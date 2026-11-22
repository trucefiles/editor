import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import 'listed_content.dart';
import 'page_leave.dart';
import 'text_edit_page_controller.dart';

/// The view page's model, for a file the app only shows (e.g. an
/// image): what it shows now, where it is, moving and deleting it, its
/// mark and settings, and whether a new one is kept as the user leaves
/// or quits. No UI. Listeners hear of every change of the file's owner,
/// and of its folder's reach.
final class ViewPageController extends ChangeNotifier {
  /// [owner] follows the file; [read] reads a listed file as it is now.
  /// [reachOf]: a folder's reach now; [reachSettled]: once a running
  /// check of it is over. [delete] deletes the file; [settingsOf] gives a
  /// file's settings, [editSettings] changes them. [endWait]: how long
  /// the app's end waits at most for a new file.
  ViewPageController(
    this._owner, {
    required this.read,
    required this.reachOf,
    required this.reachSettled,
    required this.delete,
    required this.settingsOf,
    required this.editSettings,
    required this.endWait,
  }) {
    _following = [
      _owner.changes.listen((_) => notifyListeners()),
      _owner.events.listen((event) {
        if (event is NewWritten) _added = true;
      }),
    ];
  }

  final ShownFileOwner _owner;
  final Future<Result<FileBytes, StoreError>> Function(ListedFile file) read;
  final Reach Function(FolderId folder) reachOf;
  final Future<Reach> Function(FolderId folder) reachSettled;
  final DeleteForUndo delete;
  final FileSettings Function(FileKey file) settingsOf;
  final EditSettings editSettings;
  final Duration endWait;
  late final List<StreamSubscription<Object>> _following;

  /// Whether this page added the file, and it was written.
  bool _added = false;

  /// The new file this page added, as it is now: once written, and while
  /// it is still there (not deleted, moved elsewhere by others or gone);
  /// `null` before, and for a file opened from its folder.
  ListedFile? get written => _added ? listed : null;

  ShownState get state => _owner.state;

  /// Where the file is, as its save icon shows.
  SaveState get saveState => saveStateOfShown(state);

  /// The folder the file is in or goes to; `null` once dropped.
  FolderId? get folder => folderOfShown(state);

  /// The file as listed; `null` while it is new, or once it is gone.
  ListedFile? get listed => switch (state) {
    ShownListed(:final file) => file,
    _ => null,
  };

  /// Where the file is, or goes; `null` once dropped.
  ({Folder folder, RelPath path})? get place => switch (state) {
    WaitingNew(:final file) => (folder: file.place.folder, path: file.path),
    ShownListed(:final file) ||
    ShownGone(last: final file) => (folder: file.folder, path: file.path),
    ShownDropped() => null,
  };

  /// The file's name as the user sees it, without its extension.
  String get title => switch (place) {
    final place? => nameTitle(place.path),
    null => '',
  };

  /// What the page shows of the file, by the owner's content tag, so it
  /// is drawn once while its bytes stay the same, wherever it goes;
  /// `null` once dropped.
  ShownContent? get content => switch (state) {
    WaitingNew(:final file, :final content) => ShownContent(
      content,
      () async => file.bytes,
    ),
    ShownListed(:final file, :final content) ||
    ShownGone(
      last: final file,
      :final content,
    ) => ShownContent(content, listedBytes(file, read)),
    ShownDropped() => null,
  };

  /// The folders' contents changed.
  void observe(FolderContents contents) => _owner.send(SeeFolders(contents));

  /// The reach of the file's folder changed.
  void reachChanged() => notifyListeners();

  /// Whether the file's folder can't be reached now.
  bool get unreachable => switch (folder) {
    final folder? => reachOf(folder) == Reach.unreachable,
    null => false,
  };

  /// Whether the file can be moved, deleted or marked now: it is there
  /// or still new, and its folder can be reached.
  bool get actsOnFile =>
      (state is ShownListed || state is WaitingNew) && !unreachable;

  /// The file's settings on this device; the defaults until it has a
  /// file.
  FileSettings get settings => switch (listed) {
    final file? => settingsOf(file.key),
    null => FileSettings.defaults,
  };

  /// The file's mark as [shown] holds it; none until it has a file.
  FileMark markIn(FolderFiles? shown) => switch (listed) {
    final file? => shown?.markOf(file.key) ?? FileMark.none,
    null => FileMark.none,
  };

  /// Takes the place and name the user [picked]: a new file only
  /// changes where it goes; one in its folder is moved or renamed. An
  /// empty name keeps the name it has. The file as moved, `null` where
  /// it did not move; why not, if it can't.
  Future<Result<ListedFile?, MoveFailure>> placeAt(PickedPlace picked) async {
    final title = this.title;
    final change = PlaceChange.of(
      picked,
      isNew: state is WaitingNew,
      saved: listed,
      unnamed: title,
    );
    final MoveTarget to;
    switch (change) {
      case NewPlace(:final place, :final name, :final newSubfolder):
        to = (place: place, title: name ?? title, newSubfolder: newSubfolder);
      case MoveTo(to: final target):
        to = target;
      case SamePlace():
        return const Ok(null);
      case CantMove(:final failure):
        return Err(failure);
    }
    return switch (await _place(to)) {
      final failure? => Err(failure),
      null => Ok(change is MoveTo ? listed : null),
    };
  }

  Future<MoveFailure?> _place(MoveTarget to) =>
      answerOf<ShownInput, Placed, MoveFailure?>(
        _owner,
        (ticket) => PlaceShown(
          ticket,
          to.place,
          title: to.title,
          newSubfolder: to.newSubfolder,
        ),
        read: (answer) => answer.failure,
        orElse: const MoveNotSaved(),
      );

  /// Writes a new file kept on this device into its folder now: by the
  /// rule for when the app hides, which writes to the folder first.
  Future<void> saveNow() => keep(SecureReason.hide);

  /// Tries again to keep a new file that could be kept nowhere.
  void retry() => _owner.send(const KeepNew());

  /// The file's folder left the app; whether the page may close. A new
  /// file not written yet stays open, so it can go elsewhere: its draft
  /// went with the folder, so it is kept nowhere now and the page says
  /// so.
  bool folderRemoved() {
    if (state is! WaitingNew) return true;
    _owner.send(const NewFolderRemoved());
    return false;
  }

  /// Keeps a new file for [reason]; whether it is kept: in its folder,
  /// or on this device while hidden, while its folder can't be reached,
  /// or as the app ends (within [endWait]).
  Future<bool> keep(SecureReason reason) async {
    if (reason == SecureReason.exit) return keepForExit(within: endWait);
    final folder = this.folder;
    final secured = _secure(reason);
    if (folder == null) return (await secured).kept;
    return keptOrOutOfReach(secured, () => reachSettled(folder));
  }

  /// Keeps a new file as the app ends: on this device is enough; whether
  /// it was kept within [within], so a folder that hangs never holds the
  /// app.
  Future<bool> keepForExit({required Duration within}) =>
      _secure(SecureReason.exit)
          .then((secured) => secured.kept)
          .timeout(within, onTimeout: () => false);

  Future<({bool kept, bool onDevice})> _secure(SecureReason reason) =>
      answerOf<ShownInput, Secured, ({bool kept, bool onDevice})>(
        _owner,
        (ticket) => SecureShown(ticket, reason),
        read: (answer) => (kept: answer.kept, onDevice: answer.onDevice),
        orElse: (kept: false, onDevice: false),
      );

  /// Whether the user may go for [reason] (leave, quit the app): once a
  /// new file is kept ([keep]), or the user drops it when [askToDiscard].
  Future<bool> mayGo(
    SecureReason reason,
    Future<bool> Function() askToDiscard,
  ) => mayGoOnceKept(
    keep: () => keep(reason),
    askToDiscard: askToDiscard,
    discard: () => _owner.send(const DropNew()),
  );

  /// Runs [action] on the file, writing a new one first; `false` if
  /// there is no file to act on.
  Future<bool> withFile(FutureOr<void> Function(ListedFile file) action) async {
    if (state is WaitingNew) await _secure(SecureReason.hide);
    final file = listed;
    if (file == null) return false;
    await action(file);
    return true;
  }

  /// Deletes the file; a new one is just dropped.
  Future<DeleteOutcome> deleteFile() async {
    final file = listed;
    if (state is WaitingNew) {
      _owner.send(const DropNew());
      return const NewDropped();
    }
    if (file == null) return const AlreadyGone();
    final bytes = switch (await read(file)) {
      Ok(:final value) => value.bytes,
      Err() => null,
    };
    if (bytes == null) return const AlreadyGone();
    switch (await delete(file, bytes)) {
      case Ok(:final value):
        _added = false;
        return DeletedForUndo(value);
      case Err(:final error):
        return DeleteRefused(error);
    }
  }

  /// Keeps a new file as the page closes; then the owner ends.
  Future<void> close() async {
    await _secure(SecureReason.close);
    await _owner.close();
  }

  @override
  void dispose() {
    for (final following in _following) {
      unawaited(following.cancel());
    }
    super.dispose();
  }
}
