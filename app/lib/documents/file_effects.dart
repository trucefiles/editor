import 'package:truce_core/truce_core.dart';

import '../folders/note_folder.dart';
import '../notes/note.dart';
import '../notes/note_draft.dart';
import '../notes/note_drafts.dart';
import '../notes/note_files.dart';
import '../notes/note_place.dart';
import 'document_file.dart';
import 'note_version.dart';

/// Creates a note's file holding [text] at [place], named after [title].
typedef CreateNote = Future<Result<Note, StoreError>> Function(
  NotePlace place, {
  required String title,
  required String text,
});

/// Does what one open document's file owner asks (see `file_contract.dart`):
/// keeps and drops its draft on this device, writes, creates and restores
/// its file, backs it up and keeps conflict copies. Knows where the file
/// is ([file]); answers each effect with the input that tells its result.
final class FileEffects {
  FileEffects(
    this._file, {
    required this._filesOf,
    required this._draftsOf,
    required this._create,
  });

  final NoteFiles Function(NoteFolder folder) _filesOf;
  final NoteDrafts Function(NoteFolder folder) _draftsOf;
  final CreateNote _create;

  /// One draft per open document; names it in its folder's drafts.
  final _draftId = NoteDraft.newId();

  DocumentFile _file;

  /// The draft kept last, until it is dropped; kept again where a new
  /// document goes when its place changes.
  NoteDraft? _draft;

  /// Where the file is.
  DocumentFile get file => _file;

  /// Does [effect]; its result as the file owner's input, `null` for an
  /// effect without one. Draft work starts before this returns, so drafts
  /// are kept and dropped in the order asked.
  Future<FileInput?> run(FileEffect effect) => switch (effect) {
    KeepDraft(:final id, :final base, :final text) => _keepDraft(
      id,
      base,
      text,
    ),
    DropDraft() => _dropDraft(),
    Write(:final id, :final text, :final over, :final backUpFirst) => _wrote(
      id,
      _write(text, noteOf(over.version), backUpFirst: backUpFirst),
    ),
    Create(:final id, :final text) => _wrote(id, _createFile(text)),
    Restore(:final id, :final text) => _wrote(id, _restore(text)),
    BackUpBoth(:final id, :final theirs, :final mine) => _backUpBoth(
      id,
      theirs,
      mine,
    ),
    KeepAsConflict(:final id, :final text) => _keepAsConflict(id, text),
  };

  /// The user moved or renamed the document to [copy].
  void moved(Note copy) => _file = ExistingFile(copy);

  /// What shows now descends from [version], e.g. a change from
  /// elsewhere: the file as last read.
  void follow(Version version) {
    if (_file is ExistingFile) _file = ExistingFile(noteOf(version));
  }

  /// The user picked where a new document's file goes; its draft goes
  /// along.
  void place(NewFile to) {
    final from = _file;
    _file = to;
    final draft = _draft;
    if (draft == null) return;
    if (from.folder.id != to.folder.id) {
      // Not awaited: the queue of the draft's id keeps the order.
      _draftsOf(from.folder).remove(_draftId);
    }
    _keepDraft(null, draft.base, draft.text);
  }

  Future<FileInput?> _keepDraft(EffectId? id, String? base, String text) {
    final draft = NoteDraft(
      id: _draftId,
      path: _file.pathFor(text),
      base: base,
      text: text,
    );
    _draft = draft;
    final kept = _draftsOf(_file.folder).keep(draft);
    return kept.then((kept) => id == null ? null : DraftKept(id, kept: kept));
  }

  Future<FileInput?> _dropDraft() async {
    _draft = null;
    await _draftsOf(_file.folder).remove(_draftId);
    return null;
  }

  Future<FileInput> _wrote(EffectId id, Future<WriteOutcome> write) async {
    final outcome = await write;
    return Wrote(id, outcome, endedAt: Moment.now());
  }

  Future<WriteOutcome> _write(
    String text,
    Note over, {
    required bool backUpFirst,
  }) async {
    final files = _filesOf(over.folder);
    // A failed backup never stops the write: the edits matter more.
    if (backUpFirst) await files.backUpBeforeEdit(over);
    return switch (await files.save(over, text)) {
      Ok(value: final written) => _written(written),
      Err(error: StoreError.changedSinceRead) => switch (await files.reload(
        over,
      )) {
        Ok(value: final theirs) => Changed(theirs.seen),
        Err(error: StoreError.notFound) => const WriteGone(),
        Err() => const WriteFailed(),
      },
      Err(error: StoreError.notFound) => const WriteGone(),
      Err() => const WriteFailed(),
    };
  }

  Future<WriteOutcome> _createFile(String text) async {
    final file = _file;
    if (file is! NewFile) return const WriteFailed();
    return switch (await _create(
      file.place,
      title: file.titleFor(text),
      text: text,
    )) {
      Ok(value: final created) => _written(created),
      Err() => const WriteFailed(),
    };
  }

  Future<WriteOutcome> _restore(String text) async {
    final file = _file;
    if (file is! ExistingFile) return const WriteFailed();
    final files = _filesOf(file.folder);
    return switch (await files.restore(file.note, text)) {
      Ok(value: final restored) => _written(restored),
      Err(error: StoreError.alreadyExists) => switch (await files.reload(
        file.note,
      )) {
        Ok(value: final there) => Taken(there.seen),
        Err() => const WriteFailed(),
      },
      Err() => const WriteFailed(),
    };
  }

  /// The file now holds [note].
  WriteOutcome _written(Note note) {
    _file = ExistingFile(note);
    return Written(note.seen);
  }

  Future<FileInput> _backUpBoth(EffectId id, Seen theirs, String mine) async {
    final backedUp = await _filesOf(_file.folder)
        .backUp(noteOf(theirs.version), mine);
    return BackedUp(id, ok: backedUp is Ok);
  }

  Future<FileInput> _keepAsConflict(EffectId id, String text) async {
    final kept = switch (_file) {
      ExistingFile(:final note) => await _filesOf(
        note.folder,
      ).saveAsConflict(note, text),
      NewFile() => const Err<void, StoreError>(StoreError.notFound),
    };
    return ConflictKept(id, ok: kept is Ok);
  }
}
