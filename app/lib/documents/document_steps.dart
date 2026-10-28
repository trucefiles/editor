import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../file_types/document_type.dart';
import '../file_types/document_types.dart';
import '../folders/document_folder.dart';
import '../folders/folder_lookup.dart';
import '../folders/folders_controller.dart';
import '../scan/folder_scans_controller.dart';
import '../sync_tool/base_folder_services.dart';
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

  BaseFolderServices _servicesOf(Document document) =>
      _ref.read(baseFolderServicesProvider(document.folder.base));

  DocumentMarks _marksOf(Document document) => _servicesOf(document).marks;

  FileBackups _backupsOf(Document document) => _servicesOf(document).backups;

  /// [from]'s backups become [to]'s: the document moved there. Best
  /// effort, as its color: a backup left behind still shows in Backups.
  Future<void> _moveBackups(Document from, Document to) =>
      _backupsOf(from)
          .moveAll(from: from.path, to: to.path, into: _backupsOf(to));

  /// Creates a document of [type] holding [text] at [place], named after
  /// [title], and rescans, so the grid shows the document.
  Future<Result<Document, StoreError>> create(
    DocumentPlace place, {
    required DocumentType type,
    required String title,
    required String text,
  }) async {
    final created = await _ref
        .read(documentFilesProvider(place.folder))
        .create(title, type: type, subfolder: place.subfolder, text: text);
    if (created is Ok) await _scans.refresh();
    return created;
  }

  /// Moves [document], as last saved, to [place], renamed after [title] if
  /// given (with a number if taken), with its color, settings and backups.
  /// Refused while a sync conflict of the document waits, and if its file
  /// changed since [document] was read: the user saves their edits first.
  /// Within one base folder the file itself moves; to another one it is
  /// copied, then the old file is removed. If that fails, e.g. as it
  /// changed meanwhile, both stay: never lose data. No rescan, as for
  /// [delete].
  Future<Result<Document, MoveFailure>> move(
    Document document,
    DocumentPlace place, {
    String? title,
  }) async {
    if (_conflictWaits(document)) return const Err(MoveBlockedByConflict());
    final mark = markOf(document);
    final settings = _settings.settingsOf(document.key);
    final files = _ref.read(documentFilesProvider(place.folder));
    final sameBase = place.folder.base == document.folder.base;
    final written = sameBase
        ? await files.moveIn(document, subfolder: place.subfolder, title: title)
        : await files.copyIn(
            document,
            document.file.text,
            subfolder: place.subfolder,
            title: title,
          );
    final Document moved;
    switch (written) {
      case Ok(:final value):
        moved = value;
      case Err(:final error):
        return Err(MoveNotWritten(error));
    }
    // Best effort, as the color of a new document.
    if (mark != DocumentMark.none) await _marksOf(moved).set(moved.path, mark);
    await _settings.edit(moved.key, (_) => settings);
    if (!sameBase) {
      final deleted = await _ref
          .read(documentFilesProvider(document.folder))
          .delete(document);
      if (deleted case Err(:final error)) {
        return Err(MoveLeftOriginal(moved, error));
      }
    }
    await _marksOf(document).remove(document.path);
    await _settings.forget(document.key);
    await _moveBackups(document, moved);
    return Ok(moved);
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

  /// Recovers the drafts of every base folder written before [before]
  /// (see [DraftRecovery]). Recovers none if the folders can't be loaded.
  Future<void> recoverDrafts({required DateTime before}) async {
    final folders = await _ref
        .read(foldersProvider.future)
        .then<List<DocumentFolder>>(
          (folders) => folders,
          onError: (_) => <DocumentFolder>[],
        );
    final types = _ref.read(documentTypesProvider);
    for (final base in {for (final folder in folders) folder.base}) {
      await DraftRecovery(
        _ref.read(documentDraftsProvider(base.id)),
        filesFor: (path) => switch (folders.folderOf(base.id, path)) {
          final folder? => _ref.read(documentFilesProvider(folder)),
          null => null,
        },
        types: types,
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
