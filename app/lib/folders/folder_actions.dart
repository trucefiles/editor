import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/platform_wiring.dart';
import '../platform/storage_access.dart';
import 'document_folder.dart';
import 'folder_error.dart';
import 'folder_selection.dart';
import 'folders_controller.dart';

final folderActionsProvider = Provider<FolderActions>(FolderActions.new);

/// The user's actions on the folder list: change, remove; adding goes
/// step by step (see `AddFolderFlow`). No UI: screens ask the user, then
/// call these and show the result.
final class FolderActions {
  FolderActions(this._ref);

  final Ref _ref;

  FoldersController get _folders => _ref.read(foldersProvider.notifier);
  StorageAccess get _access => _ref.read(storageAccessProvider);

  /// Whether the app may open folders; if not, [requestAccess] first.
  Future<bool> hasAccess() => _access.isGranted();

  /// Opens the system page where the user grants access to folders.
  Future<void> requestAccess() => _access.request();

  Future<Result<void, FolderError>> change(DocumentFolder changed) =>
      _folders.change(changed);

  /// Forgets [folder] (its files stay untouched), stops filtering the
  /// documents by it, and deletes its drafts: no edit is recovered into it.
  Future<Result<void, FolderError>> remove(DocumentFolder folder) {
    if (_ref.read(selectedFolderIdProvider) == folder.id) {
      _ref.read(selectedFolderIdProvider.notifier).choose(null);
    }
    return _folders.remove(folder);
  }
}
