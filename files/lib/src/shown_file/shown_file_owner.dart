import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../drafts/draft.dart';
import '../drafts/file_drafts.dart';
import '../drafts/page_draft.dart';
import '../file_bytes.dart';
import '../folder_state/folder_contents.dart';
import '../listed_file.dart';
import '../move_failure.dart';
import '../new_file_name.dart';
import '../open_file/observation.dart';
import '../page_writes.dart';
import 'new_shown_file.dart';
import 'shown_file_contract.dart';

export 'shown_file_contract.dart';

/// The owner of one shown file (see `shown_file_contract.dart`).
typedef ShownFileOwner = Owner<ShownInput, ShownState, ShownEvent>;

/// What a shown file's owner does its work with: [reload] reads a
/// listed file as it is now, [draftsOf] gives a folder's drafts on this
/// device, [create] and [move] write as the files owner does.
final class ShownWork {
  const ShownWork({
    required this.reload,
    required this.draftsOf,
    required this.create,
    required this.move,
  });

  final Future<Result<FileBytes, StoreError>> Function(ListedFile file) reload;
  final FileDrafts Function(Folder folder) draftsOf;
  final FileCreator create;
  final FileMover move;
}

/// The owner of [file], opened from its folder.
ShownFileOwner shownFileOwner(ListedFile file, ShownWork work) =>
    _ShownSteps(work)
        .ownerFrom(ShownListed(file, content: ContentTag.listed(file)));

/// The owner of [file], a new one the user just added; it is kept on
/// the device at once.
ShownFileOwner newShownFileOwner(NewShownFile file, ShownWork work) =>
    _ShownSteps(work).ownerFrom(
      WaitingNew(file, kept: NewKept.keeping, content: ContentTag.unique()),
    )..send(const KeepNew());

/// The folder [state]'s file is in, or goes to; none once dropped.
FolderId? folderOfShown(ShownState state) => switch (state) {
  WaitingNew(:final file) => file.place.folder.id,
  ShownListed(:final file) || ShownGone(last: final file) => file.folder.id,
  ShownDropped() => null,
};

/// How a shown file's owner handles each input. A new file waits as a
/// draft on the device (one per page) until the user leaves or hides the
/// app; then it is written. Its own writes end at moments, so a listing
/// that started before one never undoes it. Its content tag changes only
/// with the bytes: its own writes keep them, a listed version it didn't
/// write brings new ones.
final class _ShownSteps {
  _ShownSteps(this._work) : _draft = PageDraft(_work.draftsOf);

  final ShownWork _work;
  final PageDraft _draft;

  /// When the last own write ended; listings seen before it are old.
  Moment? _wroteAt;

  /// Equal bytes: the same list at once, else compared once per own move
  /// (as cheap as the move's own read and write).
  static const _sameBytes = ListEquality<int>();

  ShownFileOwner ownerFrom(ShownState start) =>
      SimpleOwner<ShownInput, ShownState, ShownEvent>(start, _handle);

  Future<void> _handle(
    ShownInput input,
    OwnerOutlet<ShownState, ShownEvent> out,
  ) async {
    switch (input) {
      case SeeFolders(:final contents):
        out.state = _seen(out.state, contents);
      case PlaceShown(:final ticket):
        out.emit(Placed(ticket, await _place(input, out)));
      case SecureShown(:final ticket, :final reason):
        final kept = await _secure(reason, out);
        out.emit(
          Secured(
            ticket,
            kept: kept,
            onDevice: switch (out.state) {
              WaitingNew(kept: NewKept.onDevice) => true,
              _ => false,
            },
          ),
        );
      case KeepNew():
        if (out.state case WaitingNew(:final file, :final content)) {
          await _keepNew(file, content, out);
        }
      case DropNew():
        if (out.state is WaitingNew) {
          out.state = const ShownDropped();
          await _draft.drop();
        }
      case NewFolderRemoved():
        if (out.state case WaitingNew(:final file, :final content)) {
          out.state = WaitingNew(file, kept: NewKept.nowhere, content: content);
        }
    }
  }

  /// [state] after [contents]: a listed file follows its listing, from
  /// one that saw the last own write on; its content stays while its
  /// version does.
  ShownState _seen(ShownState state, FolderContents contents) =>
      switch (state) {
        ShownListed(:final file, :final content) ||
        ShownGone(
          last: final file,
          :final content,
        ) => _followed(state, file, content, contents),
        WaitingNew() || ShownDropped() => state,
      };

  /// [state], last listed as [last] holding [content], after [contents].
  ShownState _followed(
    ShownState state,
    ListedFile last,
    ContentTag content,
    FolderContents contents,
  ) {
    final seenAt = contents.seenAt(last.key);
    final wroteAt = _wroteAt;
    if (seenAt == null || (wroteAt != null && seenAt.isBefore(wroteAt))) {
      return state;
    }
    return switch (contents.shown.observe(last.key)) {
      Found() => _listedAfter(
        last,
        content,
        contents.shown.findFile(last.key)!,
      ),
      Gone() => ShownGone(last, content: content),
      Unknown() => state,
    };
  }

  /// [found], listed after [last] held [content]: the same content while
  /// its version is the same.
  static ShownListed _listedAfter(
    ListedFile last,
    ContentTag content,
    ListedFile found,
  ) => ShownListed(
    found,
    content: found.version == last.version ? content : ContentTag.listed(found),
  );

  /// Keeps [file] on the device; where it can't be, writes it into its
  /// folder at once.
  Future<void> _keepNew(
    NewShownFile file,
    ContentTag content,
    OwnerOutlet<ShownState, ShownEvent> out,
  ) async {
    out.state = WaitingNew(file, kept: NewKept.keeping, content: content);
    if (await _keepDraft(file)) {
      out.state = WaitingNew(file, kept: NewKept.onDevice, content: content);
    } else if (!await _write(file, content, out)) {
      out.state = WaitingNew(file, kept: NewKept.nowhere, content: content);
    }
  }

  Future<bool> _keepDraft(NewShownFile file) => _draft.keep(
    file.place.folder,
    Draft(
      DraftHead(
        id: _draft.id,
        path: file.path,
        of: NewFileDraft(newSubfolder: file.newSubfolder),
      ),
      file.bytes,
    ),
  );

  /// Writes [file], holding [content], into its folder; whether it is
  /// there.
  Future<bool> _write(
    NewShownFile file,
    ContentTag content,
    OwnerOutlet<ShownState, ShownEvent> out,
  ) async {
    final (:base, :extension) = splitFileName(file.name);
    final created = await _work.create(
      file.place,
      extension: extension,
      title: base,
      bytes: file.bytes,
      newSubfolder: file.newSubfolder,
    );
    if (created case Ok(value: final written)) {
      _wroteAt = Moment.now();
      out.state = ShownListed(written.listed, content: content);
      out.emit(NewWritten(written.listed));
      await _draft.drop();
      return true;
    }
    return false;
  }

  /// Whether the file is kept lasting for [reason]: a new one is written
  /// as the user leaves or hides the app; if it can't be, it waits on the
  /// device, except while the page closes. As the app ends, the device
  /// is enough.
  Future<bool> _secure(
    SecureReason reason,
    OwnerOutlet<ShownState, ShownEvent> out,
  ) async {
    final state = out.state;
    if (state is! WaitingNew) return true;
    final onDevice = state.kept == NewKept.onDevice;
    if (reason == SecureReason.exit && onDevice) return true;
    if (await _write(state.file, state.content, out)) return true;
    return reason == SecureReason.hide && onDevice;
  }

  /// Takes the file to where [ask] says; why not, if it can't go.
  Future<MoveFailure?> _place(
    PlaceShown ask,
    OwnerOutlet<ShownState, ShownEvent> out,
  ) async {
    switch (out.state) {
      case WaitingNew(:final file, :final content):
        final to = file.at(
          ask.place,
          title: ask.title,
          newSubfolder: ask.newSubfolder,
        );
        await _keepNew(to, content, out);
        return null;
      case ShownListed(:final file, :final content):
        return _move(file, content, ask, out);
      case ShownGone() || ShownDropped():
        return const MoveNotWritten(StoreError.notFound);
    }
  }

  /// Moves [file], holding [content], where [ask] says, as the user
  /// picked it; why not, if it can't. Its content stays unless its type
  /// changed the bytes on the way.
  Future<MoveFailure?> _move(
    ListedFile file,
    ContentTag content,
    PlaceShown ask,
    OwnerOutlet<ShownState, ShownEvent> out,
  ) async {
    final FileBytes read;
    switch (await _work.reload(file)) {
      case Ok(:final value):
        read = value;
      case Err(:final error):
        return MoveNotWritten(error);
    }
    final moved = await _work.move(
      read,
      ask.place,
      title: ask.title,
      newSubfolder: ask.newSubfolder,
    );
    final copy = switch (moved) {
      Ok(:final value) ||
      Err(error: MoveLeftOriginal(copy: final value)) => value,
      Err() => null,
    };
    if (copy != null) {
      _wroteAt = Moment.now();
      out.state = ShownListed(
        copy.listed,
        content: _sameBytes.equals(copy.bytes, read.bytes)
            ? content
            : ContentTag.listed(copy.listed),
      );
    }
    return switch (moved) {
      Ok() => null,
      Err(:final error) => error,
    };
  }
}
