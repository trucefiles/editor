import 'dart:async';

import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../files/file_text.dart';
import '../files/read_version.dart';
import '../files/text_files.dart';
import '../text_file_owner/text_file_contract.dart';
import 'page_file.dart';

/// Where the user moves an open file: to [place], named after
/// [title]; [newSubfolder]: [place]'s subfolder is a new one to make.
typedef MoveTarget = ({FilePlace place, String title, bool newSubfolder});

/// The effect handler of one open file owner (see
/// `text_file_contract.dart`): keeps and drops its draft on this device,
/// reads, writes, creates, moves and restores its file, backs it up and
/// keeps conflict copies; answers each effect with the result the owner gets.
/// Each effect names the file it acts on; where it names none (a new
/// file's), it acts where the new file goes.
final class TextEditEffects {
  /// [newFile]: where a new file goes; `null` for a file
  /// opened from its file.
  TextEditEffects({
    this._newFile,
    required this._filesOf,
    required this._draftsOf,
    required this._create,
    required this._mover,
  });

  final TextFiles Function(Folder folder) _filesOf;
  final FileDrafts Function(Folder folder) _draftsOf;
  final FileCreator _create;
  final FileMover _mover;

  /// One draft per open file; names it in its folder's drafts.
  final _draftId = DraftHead.newId();

  /// Where a new file goes: the place the user last gave;
  /// `null` for a file opened from its file.
  NewFile? _newFile;

  /// Where each move the user asked goes, by its ask's ticket, and how it
  /// went once it ran.
  final _moves =
      <Ticket, ({MoveTarget to, Result<FileBytes, MoveFailure>? result})>{};

  /// The draft kept last, until it is dropped: moved along when a new
  /// file's place changes, and what the last draft builds on once the
  /// owner stopped. A new file's keeps the first line that names it, not
  /// taken from the draft's path: that holds the user's name when they
  /// gave one.
  ({FileText? base, String text, String? firstLine})? _kept;

  /// Does [effect]; its result for the file owner, `null` for an effect
  /// without one. Draft work starts before this returns, so drafts are
  /// kept and dropped in the order asked.
  Future<TextFileResult<ReadVersion>?> run(
    TextFileEffect<ReadVersion> effect,
  ) => switch (effect) {
    KeepDraft(
      :final id,
      :final base,
      :final text,
      :final file,
      :final firstLine,
    ) =>
      _keepDraft(id, base?.read, text, whereOf(file), firstLine: firstLine),
    DropDraft(:final file) => _dropDraft(whereOf(file)),
    Write(:final id, :final text, :final over, :final backUpFirst) => _wrote(
      id,
      _write(text, over.version.read, backUpFirst: backUpFirst),
    ),
    Create(:final id, :final text, :final firstLine) => _wrote(
      id,
      _createFile(text, firstLine: firstLine),
    ),
    Restore(:final id, :final text, :final where) => _wrote(
      id,
      _restore(text, where.version.read),
    ),
    ReadLatest(:final id, :final at) => _readLatest(id, at.version.read),
    MoveFile(:final id, :final ticket, :final from) => _moveFile(
      id,
      ticket,
      from.version.read,
    ),
    BackUpBoth(:final id, :final theirs, :final mine) => _backUpBoth(
      id,
      theirs.version.read,
      mine,
    ),
    KeepAsConflict(:final id, :final text, :final nextTo) => _keepAsConflict(
      id,
      text,
      nextTo.version.read,
    ),
  };

  /// The user picked where a new file goes; its draft goes along: kept
  /// at the new place first, and dropped from another folder only once
  /// kept, so it is always kept somewhere.
  void place(NewFile to) {
    final from = _newFile;
    _newFile = to;
    final kept = _kept;
    if (kept == null) return;
    // With the first line it was kept with, as its text has not changed.
    // Not awaited: the queue of the draft's id keeps the order.
    unawaited(
      _keep(kept.base, kept.text, to, firstLine: kept.firstLine).then((ok) {
        // Not once the draft went back to [from]'s folder meanwhile.
        if (ok && from != null && from.folder.id != _newFile?.folder.id) {
          unawaited(_draftsOf(from.folder).remove(_draftId));
        }
      }),
    );
  }

  /// The user moves the file to [to], by the [Move] with [ticket]:
  /// where its [MoveFile] goes.
  void aimMove(Ticket ticket, MoveTarget to) =>
      _moves[ticket] = (to: to, result: null);

  /// How the move asked with [ticket] went, once; `null` if it did not
  /// run.
  Result<FileBytes, MoveFailure>? takeMoveResult(Ticket ticket) =>
      _moves.remove(ticket)?.result;

  /// Keeps [text] as the draft without the file owner, once it stopped
  /// (a bug): over the base of the draft before, else of [file], the
  /// version the owner last named (`null` for a new file, whose file
  /// is named after [firstLine]). It goes into the file at the next start.
  /// Whether they are kept, or there was nothing to keep.
  Future<bool> keepLastDraft(
    String text, {
    required ReadVersion? file,
    required String firstLine,
  }) async {
    final base = _kept?.base ?? file?.read;
    if (text == (base?.text ?? '')) return true;
    return _keep(base, text, whereOf(file), firstLine: firstLine);
  }

  /// Where the effects on [file] act: the file, or where a new file's
  /// file goes while it has none.
  PageFile whereOf(ReadVersion? file) => switch ((file, _newFile)) {
    (final file?, _) => ExistingFile(file.read),
    (null, final place?) => place,
    // The owner names a file for every file opened from one.
    (null, null) => throw StateError('A document without file or place.'),
  };

  Future<TextFileResult<ReadVersion>> _keepDraft(
    EffectId id,
    FileText? base,
    String text,
    PageFile where, {
    required String? firstLine,
  }) => _keep(
    base,
    text,
    where,
    firstLine: firstLine,
  ).then((kept) => DraftKept(id, kept: kept));

  /// Keeps [text], edited from [base], as the draft of the file [where]
  /// is: the edited text in [base]'s byte style, over [base]'s
  /// fingerprint (by default the file's as [where] holds it); a new
  /// file's as it will be written, named after its [firstLine]. Whether
  /// it is kept.
  Future<bool> _keep(
    FileText? base,
    String text,
    PageFile where, {
    required String? firstLine,
  }) {
    _kept = (base: base, text: text, firstLine: firstLine);
    final draft = switch (where) {
      ExistingFile(:final file, :final path) => _editsDraft(
        path,
        base ?? file,
        text,
      ),
      NewFile(:final newSubfolder) => Draft(
        DraftHead(
          id: _draftId,
          path: where.pathFor(firstLine!),
          of: NewFileDraft(newSubfolder: newSubfolder),
        ),
        where.styleFor(text).encode(text),
      ),
    };
    return _draftsOf(where.folder).keep(draft);
  }

  /// The draft of [text], edited from [base], of the file at [path].
  Draft _editsDraft(RelPath path, FileText base, String text) => Draft(
    DraftHead(id: _draftId, path: path, of: OwnDraft(base.fingerprint)),
    base.textFile.encode(text),
  );

  Future<TextFileResult<ReadVersion>?> _dropDraft(PageFile where) async {
    _kept = null;
    await _draftsOf(where.folder).remove(_draftId);
    return null;
  }

  Future<TextFileResult<ReadVersion>> _wrote(
    EffectId id,
    Future<WriteOutcome<ReadVersion>> write,
  ) async {
    final outcome = await write;
    return Wrote(id, outcome, endedAt: Moment.now());
  }

  Future<TextFileResult<ReadVersion>> _readLatest(
    EffectId id,
    FileText at,
  ) async => switch (await _filesOf(at.folder).reload(at.listed)) {
    Ok(value: final now) => LatestRead(id, now.seen),
    Err() => LatestRead(id, null),
  };

  Future<WriteOutcome<ReadVersion>> _write(
    String text,
    FileText over, {
    required bool backUpFirst,
  }) async {
    final files = _filesOf(over.folder);
    // A failed backup never stops the write: the edits matter more.
    if (backUpFirst) await files.backUpBeforeEdit(over);
    return switch (await files.save(over, text)) {
      Ok(value: final written) => _written(written),
      Err(error: StoreError.changedSinceRead) => switch (await files.reload(
        over.listed,
      )) {
        Ok(value: final theirs) => Changed(theirs.seen),
        Err(error: NotRead(error: StoreError.notFound)) => const WriteGone(),
        Err(error: NotRead(error: StoreError.closed)) => const FolderClosed(),
        Err() => const WriteFailed(),
      },
      Err(error: StoreError.notFound) => const WriteGone(),
      Err(error: StoreError.closed) => const FolderClosed(),
      Err() => const WriteFailed(),
    };
  }

  Future<WriteOutcome<ReadVersion>> _createFile(
    String text, {
    required String firstLine,
  }) async {
    final file = _newFile;
    if (file == null) return const WriteFailed();
    final style = file.styleFor(text);
    return switch (await _create(
      file.place,
      extension: file.type.newFileExtension,
      title: file.titleFor(firstLine),
      bytes: style.encode(text),
      newSubfolder: file.newSubfolder,
    )) {
      Ok(value: final created) => _written(FileText(created.listed, style)),
      Err(error: StoreError.closed) => const FolderClosed(),
      Err() => const WriteFailed(),
    };
  }

  Future<WriteOutcome<ReadVersion>> _restore(
    String text,
    FileText where,
  ) async {
    final files = _filesOf(where.folder);
    return switch (await files.restore(where, text)) {
      Ok(value: final restored) => _written(restored),
      Err(error: StoreError.alreadyExists) => switch (await files.reload(
        where.listed,
      )) {
        Ok(value: final there) => Taken(there.seen),
        Err() => const WriteFailed(),
      },
      Err(error: StoreError.closed) => const FolderClosed(),
      Err() => const WriteFailed(),
    };
  }

  Future<TextFileResult<ReadVersion>> _moveFile(
    EffectId id,
    Ticket ticket,
    FileText from,
  ) async {
    final to =
        _moves[ticket]?.to ??
        (throw StateError('A move without a place to go.'));
    final moved = await _mover(
      from.fileBytes,
      to.place,
      title: to.title,
      newSubfolder: to.newSubfolder,
    );
    _moves[ticket] = (to: to, result: moved);
    final copy = switch (moved) {
      Ok(:final value) ||
      Err(error: MoveLeftOriginal(copy: final value)) => value,
      Err() => null,
    };
    return MovedTo(
      id,
      copy == null ? null : FileText.ofWritten(copy).seen,
      endedAt: Moment.now(),
    );
  }

  /// The file now holds [file].
  WriteOutcome<ReadVersion> _written(FileText file) => Written(file.seen);

  Future<TextFileResult<ReadVersion>> _backUpBoth(
    EffectId id,
    FileText file,
    String mine,
  ) async {
    final backedUp = await _filesOf(file.folder).backUp(file, mine);
    return BackedUp(id, ok: backedUp is Ok);
  }

  Future<TextFileResult<ReadVersion>> _keepAsConflict(
    EffectId id,
    String text,
    FileText nextTo,
  ) async {
    final kept = await _filesOf(nextTo.folder).saveAsConflict(nextTo, text);
    return ConflictKept(id, ok: kept is Ok);
  }
}
