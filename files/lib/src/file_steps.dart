import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'backups/folder_backups.dart';
import 'delete_failure.dart';
import 'drafts/draft.dart';
import 'drafts/draft_recovery.dart';
import 'drafts/file_drafts.dart';
import 'file_arrival.dart';
import 'file_bytes.dart';
import 'file_place.dart';
import 'file_settings_keeper.dart';
import 'files_of_folder.dart';
import 'listed_file.dart';
import 'move_failure.dart';
import 'shown_file_types.dart';
import 'undoable_delete.dart';

/// What the file steps work with, from the app's wiring.
final class FilesWork {
  const FilesWork({
    required this.files,
    required this.servicesOf,
    required this.settings,
    required this.conflictWaits,
    required this.folders,
    required this.drafts,
    required this.recoverOwnDraft,
    required this.recoverOldDrafts,
    required this.types,
    required this.arrivals,
  });

  final FileAccess files;

  /// A folder's services.
  final FolderServices Function(FolderId folder) servicesOf;

  final FileSettingsKeeper settings;

  /// Whether a sync conflict of a file waits, as last seen.
  final bool Function(FileKey key) conflictWaits;

  /// The folders once their list loaded; none if it can't be read.
  final Future<List<Folder>> Function() folders;

  /// What waits on this device to go into each folder's files.
  final DraftsByFolder drafts;

  /// Puts a draft its user keeps itself into its file (see [OwnDraft]).
  final OwnDraftRecovery recoverOwnDraft;

  /// Puts the drafts an older app version left, in its own format, into
  /// the files of [files]' folder; written before [before]. Only until
  /// those are all recovered.
  final Future<void> Function(FilesOfFolder files, {required DateTime before})
  recoverOldDrafts;

  final ShownFileTypes types;

  /// How files arrive as they move or are restored.
  final FileArrivals arrivals;
}

/// The steps of the user's actions on files: create, new subfolder,
/// move or rename, delete and undo, color, and recovering the drafts of
/// the last run. Run one at a time by the files owner, so their side
/// steps (mark, settings, backups) never mix.
base class FileSteps {
  FileSteps(this._work);

  final FilesWork _work;

  FileAccess get _files => _work.files;
  FileSettingsKeeper get _settings => _work.settings;

  FileMarks _marksOf(Folder folder) => _work.servicesOf(folder.id).marks;

  FileBackups _backupsOf(Folder folder) => _work.servicesOf(folder.id).backups;

  /// [from]'s backups become [to]'s: the file moved there. Best
  /// effort, as its color: a backup left behind still shows in Backups.
  Future<void> _moveBackups(ListedFile from, ListedFile to) =>
      _backupsOf(from.folder)
          .moveAll(from: from.path, to: to.path, into: _backupsOf(to.folder));

  /// Creates a file holding [bytes] at [place], named after [title] with
  /// [extension] (see [FilesOfFolder.create]); [newSubfolder]: [place]'s
  /// subfolder is a new one the user asked for, made first. Like every write of the app, the folder state
  /// sees it at once.
  Future<Result<FileBytes, StoreError>> create(
    FilePlace place, {
    required String extension,
    required String title,
    required Uint8List bytes,
    bool newSubfolder = false,
  }) => _files
      .of(place.folder)
      .create(
        title,
        extension: extension,
        subfolder: place.subfolder,
        newSubfolder: newSubfolder,
        bytes: bytes,
      );

  /// Moves [file], as last saved, to [place], renamed after [title] if
  /// given (with a number if taken), with its color, settings and backups;
  /// [newSubfolder]: [place]'s subfolder is a new one the user asked for,
  /// made first.
  /// Refused while a sync conflict of the file waits, and if its file
  /// changed since [file] was read: the user saves their edits first.
  /// Its folder decides how it moves ([FilesOfFolder.moveTo]); if the old
  /// file stays beside its copy, e.g. as it can't be removed, both stay
  /// with their color and settings: never lose data. It arrives there as
  /// its type says ([FileArrivals]), in the same write; if it can't, it
  /// stays.
  Future<Result<FileBytes, MoveFailure>> move(
    FileBytes file,
    FilePlace place, {
    String? title,
    bool newSubfolder = false,
  }) async {
    if (_work.conflictWaits(file.key)) {
      return const Err(MoveBlockedByConflict());
    }
    final Uint8List? arrived;
    switch (await _work.arrivals.moved(
      file.bytes,
      folder: file.folder,
      from: file.path,
      to: place,
    )) {
      case Ok(:final value):
        arrived = value;
      case Err(:final error):
        return Err(MoveNotWritten(error));
    }
    final mark = await _markOf(file.folder, file.path);
    final settings = _settings.settingsOf(file.key);
    final written = await _files
        .of(file.folder)
        .moveTo(
          _files.of(place.folder),
          file,
          subfolder: place.subfolder,
          newSubfolder: newSubfolder,
          title: title,
          holding: arrived,
        );
    final moved = switch (written) {
      Ok(:final value) => value,
      Err(error: MoveLeftOriginal(:final copy)) => copy,
      Err() => null,
    };
    if (moved == null) return written;
    // Best effort, as the color of a new file.
    if (mark != FileMark.none) {
      await _marksOf(moved.folder).set(moved.path, mark);
    }
    await _settings.edit(moved.key, (_) => settings);
    if (written is Err) return written;
    await _marksOf(file.folder).remove(file.path);
    await _settings.forget(file.key);
    await _moveBackups(file.listed, moved.listed);
    return Ok(moved);
  }

  /// Deletes [file], holding [bytes], after a backup of it, so it can
  /// still be restored from Backups once [undoDelete] is gone. Its mark
  /// and settings stay until the usual cleanup drops them, so restoring
  /// it at its place soon brings them back; they are kept for
  /// [undoDelete] too. Refused while a sync conflict of the file waits,
  /// and if no backup can be made. Fails if the file changed since [file]
  /// was read.
  Future<Result<UndoableDelete, DeleteFailure>> delete(
    ListedFile file,
    Uint8List bytes,
  ) async {
    if (_work.conflictWaits(file.key)) {
      return const Err(DeleteBlockedByConflict());
    }
    final files = _files.of(file.folder);
    if (await files.backUpBeforeDelete(file.path, bytes) is Err) {
      return const Err(DeleteNotBackedUp());
    }
    final mark = await _markOf(file.folder, file.path);
    final settings = _settings.settingsOf(file.key);
    final deleted = await files.delete(file);
    if (deleted case Err(:final error)) return Err(DeleteNotDone(error));
    return Ok((file: file, bytes: bytes, mark: mark, settings: settings));
  }

  /// Writes [deleted] back with its mark and settings, arriving at its
  /// place as its type says ([FileArrivals]; best effort). Never
  /// overwrites: if a file was created at its path meanwhile, the file
  /// comes back beside it, under the next free numbered name, and its
  /// mark, settings and backups go with it, leaving the new file its own.
  Future<Result<void, StoreError>> undoDelete(UndoableDelete deleted) async {
    final UndoableDelete(:file, :mark, :settings) = deleted;
    final bytes = await _work.arrivals.restored(
      deleted.bytes,
      folder: file.folder,
      from: file.path,
    );
    final files = _files.of(file.folder);
    final restored = switch (await files.restore(file.path, bytes)) {
      Err(error: StoreError.alreadyExists) => await files.copyIn(
        file.path,
        bytes,
        subfolder: file.path.parent,
      ),
      final restored => restored,
    };
    if (restored case Ok(value: final back)) {
      // Even no mark: else an older mark from another device would win.
      await _marksOf(back.folder).set(back.path, mark);
      await _settings.edit(back.key, (_) => settings);
      if (back.path != file.path) {
        await _marksOf(file.folder).remove(file.path);
        await _settings.forget(file.key);
        await _moveBackups(file, back.listed);
      }
    }
    return restored.map((_) {});
  }

  /// Writes [backup] as a new file at [place], named after [title] (by
  /// default its file's name, with its extension), with a number if that
  /// name is taken: never over a file. It is given no color or settings;
  /// at a deleted file's own path, the ones [delete] kept apply to it
  /// again. [newSubfolder]: [place]'s subfolder is a new one the
  /// user asked for, made first. It arrives there as its type says
  /// ([FileArrivals]; best effort).
  Future<Result<FileBytes, StoreError>> restoreAsNew(
    FolderBackup backup,
    FilePlace place, {
    String? title,
    bool newSubfolder = false,
  }) async {
    final (:folder, backup: kept) = backup;
    final Uint8List bytes;
    switch (await _backupsOf(folder).read(kept)) {
      case Ok(:final value):
        bytes = value;
      case Err(:final error):
        return Err(error);
    }
    final arrived = await _work.arrivals.restored(
      bytes,
      folder: folder,
      from: kept.filePath,
      to: place,
    );
    return _files
        .of(place.folder)
        .copyIn(
          kept.filePath,
          arrived,
          subfolder: place.subfolder,
          newSubfolder: newSubfolder,
          title: title,
        );
  }

  /// Recovers the drafts of every folder written before [before] (see
  /// [recoverFolderDrafts]). Recovers none if the folders can't be loaded.
  Future<void> recoverDrafts({required DateTime before}) async {
    for (final folder in await _work.folders()) {
      final files = _files.of(folder);
      await _work.recoverOldDrafts(files, before: before);
      await recoverFolderDrafts(
        _work.drafts.of(folder.id),
        files,
        recoverOwn: _work.recoverOwnDraft,
        before: before,
      );
    }
  }

  /// The color of the file at [path] in [folder] as it is now: read
  /// from its marks, as the folder state may not have seen a color just
  /// set. None if the marks can't be read.
  Future<FileMark> _markOf(Folder folder, RelPath path) async =>
      switch (await _marksOf(folder).markOf(path)) {
        Ok(:final value) => value,
        Err() => FileMark.none,
      };

  /// Saves [mark] for [file]; every screen shows it once the folder
  /// state sees the write. Writes nothing if [mark] is already set.
  Future<Result<void, StoreError>> setMark(
    ListedFile file,
    FileMark mark,
  ) async {
    if (mark == await _markOf(file.folder, file.path)) {
      return const Ok(null);
    }
    return _marksOf(file.folder).set(file.path, mark);
  }
}
