import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../platform/platform_wiring.dart';
import '../platform/storage_access.dart';
import 'folder_selection.dart';
import 'folders_controller.dart';

final folderActionsProvider = Provider<FolderActions>(
  (ref) => FolderActions(
    folders: ref.watch(foldersProvider.notifier),
    access: ref.watch(storageAccessProvider),
    unpickFolder: ref.read(pickedFoldersProvider.notifier).drop,
  ),
);

/// The user's actions on the folder list: change, move, remove; adding goes
/// step by step (see `AddFolderFlow`). No UI: screens ask the user, then
/// call these and show the result.
final class FolderActions {
  /// [_unpickFolder] stops filtering the files by a folder.
  FolderActions({
    required this._folders,
    required this._access,
    required this._unpickFolder,
  });

  final FoldersController _folders;
  final StorageAccess _access;
  final void Function(FolderId folderId) _unpickFolder;

  /// Whether the app may open folders; if not, [requestAccess] first.
  Future<bool> hasAccess() => _access.isGranted();

  /// Opens the system page where the user grants access to folders.
  Future<void> requestAccess() => _access.request();

  Future<Result<void, FolderError>> change(Folder changed) =>
      _folders.change(changed);

  /// Moves [moved] to place [to] in the list (0 is first): the order of
  /// the folder chips, and the first folder new files go to when nothing
  /// else decides.
  Future<Result<void, FolderError>> move(Folder moved, {required int to}) =>
      _folders.move(moved, to: to);

  /// How many files have edits kept only on this device that
  /// [remove] would delete.
  Future<int> draftsLostByRemoving(Folder folder) =>
      _folders.draftsLostByRemoving(folder);

  /// Forgets [folder] (its files stay untouched), stops filtering the
  /// files by it, and deletes its drafts: no edit is recovered into it.
  Future<Result<void, FolderError>> remove(Folder folder) {
    _unpickFolder(folder.id);
    return _folders.remove(folder);
  }
}
