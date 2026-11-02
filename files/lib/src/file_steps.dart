import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'delete_failure.dart';
import 'draft_recovery.dart';
import 'file_drafts.dart';
import 'file_place.dart';
import 'file_settings_keeper.dart';
import 'file_text.dart';
import 'files_of_folder.dart';
import 'listed_file.dart';
import 'move_failure.dart';
import 'shown_file_type.dart';
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
    required this.types,
  });

  final FileAccess files;

  /// A base folder's services, as its folders show it now.
  final BaseFolderServices Function(BaseFolder base) servicesOf;

  final FileSettingsKeeper settings;

  /// Whether a sync conflict of a file waits, as last seen.
  final bool Function(FileKey key) conflictWaits;

  /// The folders once their list loaded; none if it can't be read.
  final Future<List<Folder>> Function() folders;

  final DraftsByBase drafts;
  final ShownFileTypes types;
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

  FileMarks _marksOf(Folder folder) => _work.servicesOf(folder.base).marks;

  FileBackups _backupsOf(Folder folder) =>
      _work.servicesOf(folder.base).backups;

  /// [from]'s backups become [to]'s: the file moved there. Best
  /// effort, as its color: a backup left behind still shows in Backups.
  Future<void> _moveBackups(FileText from, FileText to) =>
      _backupsOf(from.folder)
          .moveAll(from: from.path, to: to.path, into: _backupsOf(to.folder));

  /// Creates a file of [type] holding [text] at [place], named after
  /// [title]; [newSubfolder]: [place]'s subfolder is a new one the user
  /// asked for, made first. Like every write of the app, the folder state
  /// sees it at once.
  Future<Result<FileText, StoreError>> create(
    FilePlace place, {
    required ShownFileType type,
    required String title,
    required String text,
    bool newSubfolder = false,
  }) => _files
      .of(place.folder)
      .create(
        title,
        type: type,
        subfolder: place.subfolder,
        newSubfolder: newSubfolder,
        text: text,
      );

  /// Moves [file], as last saved, to [place], renamed after [title] if
  /// given (with a number if taken), with its color, settings and backups;
  /// [newSubfolder]: [place]'s subfolder is a new one the user asked for,
  /// made first.
  /// Refused while a sync conflict of the file waits, and if its file
  /// changed since [file] was read: the user saves their edits first.
  /// Within one base folder the file itself moves; to another one it is
  /// copied, then the old file is removed. If that fails, e.g. as it
  /// changed meanwhile, both stay: never lose data.
  Future<Result<FileText, MoveFailure>> move(
    FileText file,
    FilePlace place, {
    String? title,
    bool newSubfolder = false,
  }) async {
    if (_work.conflictWaits(file.key)) {
      return const Err(MoveBlockedByConflict());
    }
    final mark = await _markOf(file.folder, file.path);
    final settings = _settings.settingsOf(file.key);
    final files = _files.of(place.folder);
    final sameBase = place.folder.base == file.folder.base;
    final written = sameBase
        ? await files.moveIn(
            file,
            subfolder: place.subfolder,
            newSubfolder: newSubfolder,
            title: title,
          )
        : await files.copyIn(
            file,
            file.text,
            subfolder: place.subfolder,
            newSubfolder: newSubfolder,
            title: title,
          );
    final FileText moved;
    switch (written) {
      case Ok(:final value):
        moved = value;
      case Err(:final error):
        return Err(MoveNotWritten(error));
    }
    // Best effort, as the color of a new file.
    if (mark != FileMark.none) {
      await _marksOf(moved.folder).set(moved.path, mark);
    }
    await _settings.edit(moved.key, (_) => settings);
    if (!sameBase) {
      final deleted = await _files.of(file.folder).delete(file.listed);
      if (deleted case Err(:final error)) {
        return Err(MoveLeftOriginal(moved, error));
      }
    }
    await _marksOf(file.folder).remove(file.path);
    await _settings.forget(file.key);
    await _moveBackups(file, moved);
    return Ok(moved);
  }

  /// Deletes [file] with its mark and settings, keeping them and its
  /// [text] for [undoDelete]. Refused while a sync conflict of the file
  /// waits. Fails if the file changed since [file] was read.
  Future<Result<UndoableDelete, DeleteFailure>> delete(
    FileText file,
    String text,
  ) async {
    if (_work.conflictWaits(file.key)) {
      return const Err(DeleteBlockedByConflict());
    }
    final mark = await _markOf(file.folder, file.path);
    final settings = _settings.settingsOf(file.key);
    final deleted = await _files.of(file.folder).delete(file.listed);
    if (deleted case Err(:final error)) return Err(DeleteNotDone(error));
    // Best effort: the next write of the marks drops it anyway.
    await _marksOf(file.folder).remove(file.path);
    await _settings.forget(file.key);
    return Ok((file: file, text: text, mark: mark, settings: settings));
  }

  /// Writes [deleted] back with its mark and settings. Never
  /// overwrites: if a file was created at its path meanwhile, the file
  /// comes back beside it, under the next free numbered name, and its
  /// backups go with it.
  Future<Result<void, StoreError>> undoDelete(UndoableDelete deleted) async {
    final UndoableDelete(:file, :text, :mark, :settings) = deleted;
    final files = _files.of(file.folder);
    final restored = switch (await files.restore(file, text)) {
      Err(error: StoreError.alreadyExists) => await files.copyIn(
        file,
        text,
        subfolder: file.path.parent,
      ),
      final restored => restored,
    };
    if (restored case Ok(value: final back)) {
      // Even no mark: else an older mark from another device would win.
      await _marksOf(back.folder).set(back.path, mark);
      await _settings.edit(back.key, (_) => settings);
      if (back.path != file.path) await _moveBackups(file, back);
    }
    return switch (restored) {
      Ok() => const Ok(null),
      Err(:final error) => Err(error),
    };
  }

  /// Recovers the drafts of every base folder written before [before]
  /// (see [DraftRecovery]). Recovers none if the folders can't be loaded.
  Future<void> recoverDrafts({required DateTime before}) async {
    final folders = await _work.folders();
    for (final base in {for (final folder in folders) folder.base}) {
      await DraftRecovery(
        _work.drafts.of(base.id),
        filesFor: (path) => switch (folders.folderOf(base.id, path)) {
          final folder? => _files.of(folder),
          null => null,
        },
        types: _work.types,
      ).recover(before: before);
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
