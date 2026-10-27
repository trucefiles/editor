import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/document_folder.dart';
import '../folders/folders_controller.dart';
import '../scan/folder_scans_controller.dart';
import '../sync_tool/folder_services.dart';
import 'delete_failure.dart';
import 'deleted_note.dart';
import 'document.dart';
import 'document_drafts.dart';
import 'document_files.dart';
import 'document_place.dart';
import 'document_settings_controller.dart';
import 'draft_recovery.dart';
import 'move_failure.dart';

final documentStepsProvider = Provider<DocumentSteps>(DocumentSteps.new);

/// The steps of the user's actions on documents: create, move or rename,
/// delete and undo, color, and recovering the drafts of the last run. Run
/// one at a time by the documents owner, so their side steps (mark,
/// settings, backups) never mix.
base class DocumentSteps {
  DocumentSteps(this._ref);

  final Ref _ref;

  FolderScansController get _scans => _ref.read(folderScansProvider.notifier);

  DocumentSettingsController get _settings =>
      _ref.read(documentSettingsProvider.notifier);

  DocumentMarks _marksOf(Document document) =>
      _ref.read(folderServicesProvider(document.folder.location)).marks;

  FileBackups _backupsOf(Document document) =>
      _ref.read(folderServicesProvider(document.folder.location)).backups;

  /// [from]'s backups become [to]'s: the document moved there. Best
  /// effort, as its color: a backup left behind still shows in Backups.
  Future<void> _moveBackups(Document from, Document to) =>
      _backupsOf(from)
          .moveAll(from: from.path, to: to.path, into: _backupsOf(to));

  /// Creates a document holding [text] at [place], named after [title], and
  /// rescans, so the grid shows the document.
  Future<Result<Document, StoreError>> create(
    DocumentPlace place, {
    required String title,
    required String text,
  }) async {
    final created = await _ref
        .read(documentFilesProvider(place.folder))
        .create(title, subfolder: place.subfolder, text: text);
    if (created is Ok) await _scans.refresh();
    return created;
  }

  /// Moves [document], holding [text], to [place], renamed after [title] if
  /// given: writes it there under that name (with a number if taken), in
  /// its byte style, with its color and settings, then removes the old
  /// file; its backups follow once the old file is gone. Refused while a sync conflict of
  /// the document waits. If the old file can't be removed, e.g. as it changed
  /// since [document] was read, both stay: never lose data. No rescan, as for
  /// [delete].
  Future<Result<Document, MoveFailure>> move(
    Document document,
    String text,
    DocumentPlace place, {
    String? title,
  }) async {
    if (_conflictWaits(document)) return const Err(MoveBlockedByConflict());
    final mark = markOf(document);
    final settings = _settings.settingsOf(document.key);
    final copied = await _ref
        .read(documentFilesProvider(place.folder))
        .copyIn(document, text, subfolder: place.subfolder, title: title);
    final Document copy;
    switch (copied) {
      case Ok(:final value):
        copy = value;
      case Err(:final error):
        return Err(MoveNotWritten(error));
    }
    // Best effort, as the color of a new document.
    if (mark != DocumentMark.none) await _marksOf(copy).set(copy.path, mark);
    await _settings.edit(copy.key, (_) => settings);
    final deleted = await _ref
        .read(documentFilesProvider(document.folder))
        .delete(document);
    if (deleted case Err(:final error)) {
      return Err(MoveLeftOriginal(copy, error));
    }
    await _marksOf(document).remove(document.path);
    await _settings.forget(document.key);
    await _moveBackups(document, copy);
    return Ok(copy);
  }

  /// Deletes [document] with its mark and settings, keeping them and its
  /// [text] for [undoDelete]. Refused while a sync conflict of the document
  /// waits. Fails if the file changed since [document] was read. No rescan:
  /// the open editor would take the document as deleted elsewhere; it rescans
  /// as it closes.
  Future<Result<DeletedNote, DeleteFailure>> delete(
    Document document,
    String text,
  ) async {
    if (_conflictWaits(document)) return const Err(DeleteBlockedByConflict());
    final mark = markOf(document);
    final settings = _settings.settingsOf(document.key);
    final deleted = await _ref
        .read(documentFilesProvider(document.folder))
        .delete(document);
    if (deleted case Err(:final error)) return Err(DeleteNotDone(error));
    // Best effort: the next write of the marks drops it anyway.
    await _marksOf(document).remove(document.path);
    await _settings.forget(document.key);
    return Ok((document: document, text: text, mark: mark, settings: settings));
  }

  /// Writes [deleted] back with its mark and settings, and rescans. Never
  /// overwrites: if a file was created at its path meanwhile, the document
  /// comes back beside it, under the next free numbered name, and its
  /// backups go with it.
  Future<Result<void, StoreError>> undoDelete(DeletedNote deleted) async {
    final DeletedNote(:document, :text, :mark, :settings) = deleted;
    final files = _ref.read(documentFilesProvider(document.folder));
    final restored = switch (await files.restore(document, text)) {
      Err(error: StoreError.alreadyExists) => await files.copyIn(
        document,
        text,
        subfolder: document.path.parent,
      ),
      final restored => restored,
    };
    if (restored case Ok(value: final back)) {
      // Even no mark: else an older mark from another device would win.
      await _marksOf(back).set(back.path, mark);
      await _settings.edit(back.key, (_) => settings);
      if (back.path != document.path) await _moveBackups(document, back);
    }
    await _scans.refresh();
    return switch (restored) {
      Ok() => const Ok(null),
      Err(:final error) => Err(error),
    };
  }

  /// Recovers the drafts of every folder written before [before] (see
  /// [DraftRecovery]). Recovers none if the folders can't be loaded.
  Future<void> recoverDrafts({required DateTime before}) async {
    final folders = await _ref
        .read(foldersProvider.future)
        .then<List<DocumentFolder>>(
          (folders) => folders,
          onError: (_) => <DocumentFolder>[],
        );
    for (final folder in folders) {
      await DraftRecovery(
        _ref.read(documentDraftsProvider(folder.id)),
        _ref.read(documentFilesProvider(folder)),
      ).recover(before: before);
    }
  }

  /// Whether a sync conflict of [document] waits, as last scanned.
  bool _conflictWaits(Document document) =>
      _ref.read(folderScansProvider).value?.conflicts.forNote(document.key) !=
      null;

  /// [document]'s color, as last scanned.
  DocumentMark markOf(Document document) =>
      _ref.read(folderScansProvider).value?.markOf(document.key) ??
      DocumentMark.none;

  /// Saves [mark] for [document] and rescans, so every screen shows it. Writes
  /// nothing if [mark] is already set.
  Future<Result<void, StoreError>> setMark(
    Document document,
    DocumentMark mark,
  ) async {
    if (mark == markOf(document)) return const Ok(null);
    final saved = await _marksOf(document).set(document.path, mark);
    await _scans.refresh();
    return saved;
  }
}
