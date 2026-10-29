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
    selectedFolderId: () => ref.read(selectedFolderIdProvider),
    chooseFolder: ref.read(selectedFolderIdProvider.notifier).choose,
  ),
);

/// The user's actions on the folder list: change, remove; adding goes
/// step by step (see `AddFolderFlow`). No UI: screens ask the user, then
/// call these and show the result.
final class FolderActions {
  /// [_selectedFolderId] tells which folder the documents are filtered
  /// to; [_chooseFolder] filters them to another one (`null`: all).
  FolderActions({
    required this._folders,
    required this._access,
    required this._selectedFolderId,
    required this._chooseFolder,
  });

  final FoldersController _folders;
  final StorageAccess _access;
  final String? Function() _selectedFolderId;
  final void Function(String? folderId) _chooseFolder;

  /// Whether the app may open folders; if not, [requestAccess] first.
  Future<bool> hasAccess() => _access.isGranted();

  /// Opens the system page where the user grants access to folders.
  Future<void> requestAccess() => _access.request();

  Future<Result<void, FolderError>> change(DocumentFolder changed) =>
      _folders.change(changed);

  /// How many documents have edits kept only on this device that
  /// [remove] would delete.
  Future<int> draftsLostByRemoving(DocumentFolder folder) =>
      _folders.draftsLostByRemoving(folder);

  /// Forgets [folder] (its files stay untouched), stops filtering the
  /// documents by it, and deletes its drafts: no edit is recovered into it.
  Future<Result<void, FolderError>> remove(DocumentFolder folder) {
    if (_selectedFolderId() == folder.id) _chooseFolder(null);
    return _folders.remove(folder);
  }
}
