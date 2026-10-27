import 'package:truce_core/truce_core.dart';

import '../documents/document.dart';
import '../documents/document_draft.dart';
import '../documents/document_drafts.dart';
import '../documents/document_files.dart';
import '../documents/document_place.dart';
import '../folders/document_folder.dart';
import 'document_file.dart';
import 'document_version.dart';

/// Creates a document's file holding [text] at [place], named after [title].
typedef CreateNote = Future<Result<Document, StoreError>> Function(
  DocumentPlace place, {
  required String title,
  required String text,
});

/// The effect handler of one open document's file owner (see
/// `file_contract.dart`): keeps and drops its draft on this device,
/// writes, creates and restores its file, backs it up and keeps conflict
/// copies; answers each effect with the result the owner gets. Where an
/// effect names a version of the file, it acts on that version's
/// document; drafts and a new document's file go where the file is now
/// ([file]).
final class FileEffects {
  FileEffects(
    this._file, {
    required this._filesOf,
    required this._draftsOf,
    required this._create,
  });

  final DocumentFiles Function(DocumentFolder folder) _filesOf;
  final DocumentDrafts Function(DocumentFolder folder) _draftsOf;
  final CreateNote _create;

  /// One draft per open document; names it in its folder's drafts.
  final _draftId = DocumentDraft.newId();

  DocumentFile _file;

  /// The draft kept last, until it is dropped; kept again where a new
  /// document goes when its place changes.
  DocumentDraft? _draft;

  /// Where the file is: where it was created or the user moved it, or
  /// where a new document's file goes.
  DocumentFile get file => _file;

  /// Does [effect]; its result for the file owner, `null` for an effect
  /// without one. Draft work starts before this returns, so drafts are
  /// kept and dropped in the order asked.
  Future<FileResult?> run(FileEffect effect) => switch (effect) {
    KeepDraft(:final id, :final base, :final text) => _keepDraft(
      id,
      base,
      text,
    ),
    DropDraft() => _dropDraft(),
    Write(:final id, :final text, :final over, :final backUpFirst) => _wrote(
      id,
      _write(text, documentOf(over.version), backUpFirst: backUpFirst),
    ),
    Create(:final id, :final text) => _wrote(id, _createFile(text)),
    Restore(:final id, :final text, :final where) => _wrote(
      id,
      _restore(text, documentOf(where.version)),
    ),
    BackUpBoth(:final id, :final theirs, :final mine) => _backUpBoth(
      id,
      theirs,
      mine,
    ),
    KeepAsConflict(:final id, :final text, :final nextTo) => _keepAsConflict(
      id,
      text,
      documentOf(nextTo.version),
    ),
  };

  /// The user moved or renamed the document to [copy].
  void moved(Document copy) => _file = ExistingFile(copy);

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

  Future<FileResult?> _keepDraft(EffectId? id, String? base, String text) {
    final draft = DocumentDraft(
      id: _draftId,
      path: _file.pathFor(text),
      base: base,
      text: text,
    );
    _draft = draft;
    final kept = _draftsOf(_file.folder).keep(draft);
    return kept.then((kept) => id == null ? null : DraftKept(id, kept: kept));
  }

  Future<FileResult?> _dropDraft() async {
    _draft = null;
    await _draftsOf(_file.folder).remove(_draftId);
    return null;
  }

  Future<FileResult> _wrote(EffectId id, Future<WriteOutcome> write) async {
    final outcome = await write;
    return Wrote(id, outcome, endedAt: Moment.now());
  }

  Future<WriteOutcome> _write(
    String text,
    Document over, {
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

  Future<WriteOutcome> _restore(String text, Document where) async {
    final files = _filesOf(where.folder);
    return switch (await files.restore(where, text)) {
      Ok(value: final restored) => _written(restored),
      Err(error: StoreError.alreadyExists) => switch (await files.reload(
        where,
      )) {
        Ok(value: final there) => Taken(there.seen),
        Err() => const WriteFailed(),
      },
      Err() => const WriteFailed(),
    };
  }

  /// The file now holds [document].
  WriteOutcome _written(Document document) {
    _file = ExistingFile(document);
    return Written(document.seen);
  }

  Future<FileResult> _backUpBoth(EffectId id, Seen theirs, String mine) async {
    final document = documentOf(theirs.version);
    final backedUp = await _filesOf(document.folder).backUp(document, mine);
    return BackedUp(id, ok: backedUp is Ok);
  }

  Future<FileResult> _keepAsConflict(
    EffectId id,
    String text,
    Document nextTo,
  ) async {
    final kept = await _filesOf(nextTo.folder).saveAsConflict(nextTo, text);
    return ConflictKept(id, ok: kept is Ok);
  }
}
