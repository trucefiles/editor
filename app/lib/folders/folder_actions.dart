import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../platform/platform_wiring.dart';
import '../platform/storage_access.dart';
import '../settings/device_settings_controller.dart';
import 'folder_selection.dart';
import 'folders_controller.dart';

final folderActionsProvider = Provider<FolderActions>(
  (ref) => FolderActions(
    folders: ref.watch(foldersProvider.notifier),
    access: ref.watch(storageAccessProvider),
    unpickFolder: ref.read(pickedFoldersProvider.notifier).drop,
    forgetFolder: (folder) => ref
        .read(deviceSettingsProvider.notifier)
        .change((s) => s.copyWith(home: s.home.forgetting(folder))),
  ),
);

/// The user's actions on the folder list: change, move, remove; adding goes
/// step by step (see `AddFolderFlow`). No UI: screens ask the user, then
/// call these and show the result.
final class FolderActions {
  /// [_unpickFolder] stops filtering the files by a folder;
  /// [_forgetFolder] drops what this device's settings keep for one.
  FolderActions({
    required this._folders,
    required this._access,
    required this._unpickFolder,
    required this._forgetFolder,
  });

  final FoldersController _folders;
  final StorageAccess _access;
  final void Function(FolderId folderId) _unpickFolder;
  final Future<void> Function(FolderId folderId) _forgetFolder;

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
  /// Once it is gone, this device's settings forget it too.
  Future<Result<void, FolderError>> remove(Folder folder) async {
    _unpickFolder(folder.id);
    final removed = await _folders.remove(folder);
    if (removed is Ok) await _forgetFolder(folder.id);
    return removed;
  }
}
