import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../folder_state/folder_state_controller.dart';
import '../folders/folder_selection.dart';
import '../folders/open_folders_wiring.dart';
import '../reach/folder_reach_controller.dart';
import '../settings/device_settings_controller.dart';
import 'file_type_selection.dart';
import 'files_wiring.dart';

final fileActionsProvider = Provider<FileActions>(
  (ref) => FileActions(
    owner: ref.watch(filesProvider).owner,
    pickedFolders: () => ref.read(pickedFoldersProvider),
    revealFolder: ref.read(pickedFoldersProvider.notifier).reveal,
    revealType: ref.read(pickedFileTypesProvider.notifier).reveal,
    reachOf: (folder) => ref.read(folderReachProvider(folder)),
    newFilePlace: () =>
        ref.read(deviceSettingsProvider).requireValue.newFilePlace,
    contents: () => ref.read(folderContentsProvider).value,
    showsFolder: (folder, subfolder) =>
        ref.read(folderServicesProvider(folder)).open.showsFolder(subfolder),
    read: (file) => ref.read(fileAccessProvider).of(file.folder).reload(file),
  ),
);

/// The user's actions on files, and what screens need to offer them.
/// No UI: screens ask the user, then call these and show the result. Each
/// action runs in the files [owner], after the ones asked before it.
final class FileActions {
  /// What the screens show now: [_pickedFolders], the folders the grid
  /// is filtered to; [_revealFolder] and [_revealType] make the grid's
  /// filters let a folder's or a type's files through; [_reachOf], each folder's reach; [_newFilePlace], the
  /// place set for new files; [_contents], what the folders hold, as
  /// last seen (`null` before the first listing); [_showsFolder], whether a
  /// folder shows the files in one of its subfolders; [_read], a file's
  /// text as it is now.
  FileActions({
    required this._owner,
    required this._pickedFolders,
    required this._revealFolder,
    required this._revealType,
    required this._reachOf,
    required this._newFilePlace,
    required this._contents,
    required this._showsFolder,
    required this._read,
  });

  final FilesOwner _owner;
  final Set<FolderId> Function() _pickedFolders;
  final void Function(FolderId folder) _revealFolder;
  final void Function(FileType type) _revealType;
  final Reach Function(FolderId folder) _reachOf;
  final NewFilePlaceSetting? Function() _newFilePlace;
  final FolderContents? Function() _contents;
  final bool Function(FolderId folder, RelPath subfolder) _showsFolder;
  final Future<Result<FileText, OpenFailure>> Function(ListedFile file) _read;

  /// Reads [file] to open it: its text as it is now.
  Future<Result<FileText, OpenFailure>> read(ListedFile file) => _read(file);

  /// Those of [folders] that new files can go into: the ones that can be
  /// reached.
  List<Folder> reachableOf(List<Folder> folders) => [
    for (final folder in folders)
      if (_reachOf(folder.id) != Reach.unreachable) folder,
  ];

  /// Where a new file goes among [folders] (see [newFilePlaceIn]); `null`
  /// if none of them can be reached.
  FilePlace? newFilePlace(List<Folder> folders) => newFilePlaceIn(
    reachableOf(folders),
    set: _newFilePlace(),
    filtered: _pickedFolders(),
  );

  /// Makes the grid show a new file of [type] at [place], which the
  /// folders or types picked might otherwise hide.
  void reveal(FilePlace place, FileType type) {
    _revealFolder(place.folder.id);
    _revealType(type);
  }

  /// The subfolders of [folder], as last seen.
  List<RelPath> subfoldersOf(Folder folder) =>
      _contents()?.subfoldersOf(folder.id) ?? const [];

  /// Whether files of [folder] can go into [subfolder], an existing
  /// one or a new one: one whose files the folder shows (e.g. none of its
  /// sync tool's own, no hidden one).
  bool canHold(Folder folder, RelPath subfolder) =>
      _showsFolder(folder.id, subfolder);

  /// [file]'s color, as last seen.
  FileMark markOf(ListedFile file) =>
      _contents()?.markOf(file.key) ?? FileMark.none;

  /// See [FileSteps.create].
  Future<Result<FileText, StoreError>> create(
    FilePlace place, {
    required ShownFileType type,
    required String title,
    required String text,
    bool newSubfolder = false,
  }) => answerOf(
    _owner,
    (ticket) => CreateFile(
      ticket,
      place,
      type: type,
      title: title,
      text: text,
      newSubfolder: newSubfolder,
    ),
    read: (FileCreated answer) => answer.result,
    orElse: const Err(_notRun),
  );

  /// See [FileSteps.move].
  Future<Result<FileText, MoveFailure>> move(
    FileText file,
    FilePlace place, {
    String? title,
    bool newSubfolder = false,
  }) => answerOf(
    _owner,
    (ticket) => MoveFileTo(
      ticket,
      file,
      place,
      title: title,
      newSubfolder: newSubfolder,
    ),
    read: (FileMoved answer) => answer.result,
    orElse: const Err(MoveNotWritten(_notRun)),
  );

  /// See [FileSteps.delete].
  Future<Result<UndoableDelete, DeleteFailure>> delete(
    FileText file,
    String text,
  ) => answerOf(
    _owner,
    (ticket) => DeleteFile(ticket, file, text),
    read: (FileDeleted answer) => answer.result,
    orElse: const Err(DeleteNotDone(_notRun)),
  );

  /// See [FileSteps.undoDelete].
  Future<Result<void, StoreError>> undoDelete(UndoableDelete deleted) =>
      answerOf(
        _owner,
        (ticket) => UndoDelete(ticket, deleted),
        read: (DeleteUndone answer) => answer.result,
        orElse: const Err(_notRun),
      );

  /// See [FileSteps.setMark].
  Future<Result<void, StoreError>> setMark(ListedFile file, FileMark mark) =>
      answerOf(
        _owner,
        (ticket) => SetMark(ticket, file, mark),
        read: (MarkSet answer) => answer.result,
        orElse: const Err(_notRun),
      );
}

/// How an action fails that never ran, as its owner had ended (a bug in
/// an earlier action, or the app ends): to the user, nothing was written,
/// so it reads as a failed write.
const _notRun = StoreError.ioFailure;
