import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/folder_picker.dart';
import '../platform/storage_access.dart';
import 'add_folder_error.dart';
import 'folder_selection.dart';
import 'folder_settings_store.dart';
import 'folders_controller.dart';
import 'note_folder.dart';

final folderActionsProvider = Provider<FolderActions>(FolderActions.new);

/// The user's actions on the folder list: add, change, remove. No UI:
/// screens ask the user, then call these and show the result.
final class FolderActions {
  FolderActions(this._ref);

  final Ref _ref;

  FoldersController get _folders => _ref.read(foldersProvider.notifier);
  StorageAccess get _access => _ref.read(storageAccessProvider);

  /// Whether the app may open folders; if not, [requestAccess] first.
  Future<bool> hasAccess() => _access.isGranted();

  /// Opens the system page where the user grants access to folders.
  Future<void> requestAccess() => _access.request();

  /// Lets the user pick a folder and adds it. Doing nothing if the user
  /// cancels, or the folder is already added, counts as success.
  Future<Result<void, AddFolderError>> pickAndAdd() async {
    switch (await _ref.read(folderPickerProvider).pick()) {
      case Ok(value: final path?):
        return _folders.add(path);
      case Ok():
        return const Ok(null);
      case Err(error: PickError.unsupportedLocation):
        return const Err(AddFolderError.unsupportedLocation);
    }
  }

  Future<Result<void, SettingsError>> change(NoteFolder changed) =>
      _folders.change(changed);

  /// Forgets [folder] (its files stay untouched) and stops filtering the
  /// notes by it.
  Future<Result<void, SettingsError>> remove(NoteFolder folder) {
    if (_ref.read(selectedFolderIdProvider) == folder.id) {
      _ref.read(selectedFolderIdProvider.notifier).choose(null);
    }
    return _folders.remove(folder);
  }
}
