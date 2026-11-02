import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../folder_state/folder_state_controller.dart';
import '../folders/folder_selection.dart';
import '../reach/folder_reach_controller.dart';
import '../settings/device_settings_controller.dart';
import '../sync_tool/base_folder_wiring.dart';
import 'files_wiring.dart';

final fileActionsProvider = Provider<FileActions>(
  (ref) => FileActions(
    owner: ref.watch(filesProvider).owner,
    selectedFolderId: () => ref.read(selectedFolderIdProvider),
    reachOf: (base) => ref.read(folderReachProvider(base)),
    newFilePlace: () =>
        ref.read(deviceSettingsProvider).requireValue.newFilePlace,
    contents: () => ref.read(folderContentsProvider).value,
    showsFolder: (base) => ref.read(showsFolderProvider(base)),
  ),
);

/// The user's actions on files, and what screens need to offer them.
/// No UI: screens ask the user, then call these and show the result. Each
/// action runs in the files [owner], after the ones asked before it.
final class FileActions {
  /// What the screens show now: [_selectedFolderId], the folder the grid is
  /// filtered to; [_reachOf], each base folder's reach; [_newFilePlace], the
  /// place set for new files; [_contents], what the folders hold, as
  /// last seen (`null` before the first listing); [_showsFolder], whether a
  /// base folder's sync tool shows a folder.
  FileActions({
    required this._owner,
    required this._selectedFolderId,
    required this._reachOf,
    required this._newFilePlace,
    required this._contents,
    required this._showsFolder,
  });

  final FilesOwner _owner;
  final String? Function() _selectedFolderId;
  final Reach Function(BaseFolder base) _reachOf;
  final NewFilePlaceSetting? Function() _newFilePlace;
  final FolderContents? Function() _contents;
  final bool Function(RelPath folder) Function(BaseFolder base) _showsFolder;

  /// Where a new file goes without a place set for new files:
  /// the one of [folders] the grid is filtered to, else the first.
  /// [folders] must not be empty.
  Folder defaultFolder(List<Folder> folders) {
    final selected = _selectedFolderId();
    return folders.where((folder) => folder.id == selected).firstOrNull ??
        folders.first;
  }

  /// Those of [folders] that new files can go into: the ones that can be
  /// reached.
  List<Folder> reachableOf(List<Folder> folders) => [
    for (final folder in folders)
      if (_reachOf(folder.base) != Reach.unreachable) folder,
  ];

  /// Where a new file goes: the place the user set for new files,
  /// if its folder is one of [folders], else the [defaultFolder] of
  /// [folders].
  FilePlace newFilePlace(List<Folder> folders) =>
      resolveNewFilePlace(_newFilePlace(), folders) ??
      topOf(defaultFolder(folders));

  /// The subfolders of [folder], as last seen.
  List<RelPath> subfoldersOf(Folder folder) =>
      _contents()?.subfoldersOf(folder.id) ?? const [];

  /// Whether files of [folder] can go into [subfolder], an existing
  /// one or a new one: inside what the folder shows, in folders its sync
  /// tool shows (e.g. none of its own, no hidden one).
  bool canHold(Folder folder, RelPath subfolder) =>
      folder.selection.covers(subfolder) &&
      _showsFolder(folder.base)(subfolder);

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
