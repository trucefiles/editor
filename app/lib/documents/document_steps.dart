import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../file_types/document_type.dart';
import '../file_types/document_types.dart';
import '../folder_state/folder_state_controller.dart';
import '../folders/document_folder.dart';
import '../folders/folder_lookup.dart';
import '../folders/folders_controller.dart';
import '../sync_tool/base_folder_services.dart';
import 'delete_failure.dart';
import 'deleted_document.dart';
import 'document.dart';
import 'document_drafts.dart';
import 'document_files.dart';
import 'document_place.dart';
import 'document_settings_controller.dart';
import 'document_text.dart';
import 'draft_recovery.dart';
import 'move_failure.dart';

final documentStepsProvider = Provider<DocumentSteps>(DocumentSteps.new);

/// The steps of the user's actions on documents: create, new subfolder,
/// move or rename, delete and undo, color, and recovering the drafts of
/// the last run. Run one at a time by the documents owner, so their side
/// steps (mark, settings, backups) never mix.
base class DocumentSteps {
  DocumentSteps(this._ref);

  final Ref _ref;

  DocumentSettingsController get _settings =>
      _ref.read(documentSettingsProvider.notifier);

  BaseFolderServices _servicesOf(DocumentFolder folder) =>
      _ref.read(baseFolderServicesProvider(folder.base));

  DocumentMarks _marksOf(DocumentFolder folder) => _servicesOf(folder).marks;

  FileBackups _backupsOf(DocumentFolder folder) => _servicesOf(folder).backups;

  /// [from]'s backups become [to]'s: the document moved there. Best
  /// effort, as its color: a backup left behind still shows in Backups.
  Future<void> _moveBackups(DocumentText from, DocumentText to) =>
      _backupsOf(from.folder)
          .moveAll(from: from.path, to: to.path, into: _backupsOf(to.folder));

  /// Creates a document of [type] holding [text] at [place], named after
  /// [title]; [newSubfolder]: [place]'s subfolder is a new one the user
  /// asked for, made first. Like every write of the app, the folder state
  /// sees it at once.
  Future<Result<DocumentText, StoreError>> create(
    DocumentPlace place, {
    required DocumentType type,
    required String title,
    required String text,
    bool newSubfolder = false,
  }) => _ref
      .read(documentFilesProvider(place.folder))
      .create(
        title,
        type: type,
        subfolder: place.subfolder,
        newSubfolder: newSubfolder,
        text: text,
      );

  /// Moves [document], as last saved, to [place], renamed after [title] if
  /// given (with a number if taken), with its color, settings and backups;
  /// [newSubfolder]: [place]'s subfolder is a new one the user asked for,
  /// made first.
  /// Refused while a sync conflict of the document waits, and if its file
  /// changed since [document] was read: the user saves their edits first.
  /// Within one base folder the file itself moves; to another one it is
  /// copied, then the old file is removed. If that fails, e.g. as it
  /// changed meanwhile, both stay: never lose data.
  Future<Result<DocumentText, MoveFailure>> move(
    DocumentText document,
    DocumentPlace place, {
    String? title,
    bool newSubfolder = false,
  }) async {
    if (_conflictWaits(document.key)) {
      return const Err(MoveBlockedByConflict());
    }
    final mark = await _markOf(document.folder, document.path);
    final settings = _settings.settingsOf(document.key);
    final files = _ref.read(documentFilesProvider(place.folder));
    final sameBase = place.folder.base == document.folder.base;
    final written = sameBase
        ? await files.moveIn(
            document,
            subfolder: place.subfolder,
            newSubfolder: newSubfolder,
            title: title,
          )
        : await files.copyIn(
            document,
            document.text,
            subfolder: place.subfolder,
            newSubfolder: newSubfolder,
            title: title,
          );
    final DocumentText moved;
    switch (written) {
      case Ok(:final value):
        moved = value;
      case Err(:final error):
        return Err(MoveNotWritten(error));
    }
    // Best effort, as the color of a new document.
    if (mark != DocumentMark.none) {
      await _marksOf(moved.folder).set(moved.path, mark);
    }
    await _settings.edit(moved.key, (_) => settings);
    if (!sameBase) {
      final deleted = await _ref
          .read(documentFilesProvider(document.folder))
          .delete(document.document);
      if (deleted case Err(:final error)) {
        return Err(MoveLeftOriginal(moved, error));
      }
    }
    await _marksOf(document.folder).remove(document.path);
    await _settings.forget(document.key);
    await _moveBackups(document, moved);
    return Ok(moved);
  }

  /// Deletes [document] with its mark and settings, keeping them and its
  /// [text] for [undoDelete]. Refused while a sync conflict of the document
  /// waits. Fails if the file changed since [document] was read.
  Future<Result<DeletedDocument, DeleteFailure>> delete(
    DocumentText document,
    String text,
  ) async {
    if (_conflictWaits(document.key)) {
      return const Err(DeleteBlockedByConflict());
    }
    final mark = await _markOf(document.folder, document.path);
    final settings = _settings.settingsOf(document.key);
    final deleted = await _ref
        .read(documentFilesProvider(document.folder))
        .delete(document.document);
    if (deleted case Err(:final error)) return Err(DeleteNotDone(error));
    // Best effort: the next write of the marks drops it anyway.
    await _marksOf(document.folder).remove(document.path);
    await _settings.forget(document.key);
    return Ok((document: document, text: text, mark: mark, settings: settings));
  }

  /// Writes [deleted] back with its mark and settings. Never
  /// overwrites: if a file was created at its path meanwhile, the document
  /// comes back beside it, under the next free numbered name, and its
  /// backups go with it.
  Future<Result<void, StoreError>> undoDelete(DeletedDocument deleted) async {
    final DeletedDocument(:document, :text, :mark, :settings) = deleted;
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
      await _marksOf(back.folder).set(back.path, mark);
      await _settings.edit(back.key, (_) => settings);
      if (back.path != document.path) await _moveBackups(document, back);
    }
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

  /// Whether a sync conflict of the document at [key] waits, as last seen.
  bool _conflictWaits(DocumentKey key) =>
      _ref.read(folderContentsProvider).value?.conflicts.forDocument(key) !=
      null;

  /// The color of the document at [path] in [folder] as it is now: read
  /// from its marks, as the folder state may not have seen a color just
  /// set. None if the marks can't be read.
  Future<DocumentMark> _markOf(DocumentFolder folder, RelPath path) async =>
      switch (await _marksOf(folder).markOf(path)) {
        Ok(:final value) => value,
        Err() => DocumentMark.none,
      };

  /// Saves [mark] for [document]; every screen shows it once the folder
  /// state sees the write. Writes nothing if [mark] is already set.
  Future<Result<void, StoreError>> setMark(
    Document document,
    DocumentMark mark,
  ) async {
    if (mark == await _markOf(document.folder, document.path)) {
      return const Ok(null);
    }
    return _marksOf(document.folder).set(document.path, mark);
  }
}
