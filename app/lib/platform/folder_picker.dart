import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks the user for a folder on this device.
abstract interface class FolderPicker {
  /// Absolute path of the chosen folder; `null` if the user cancelled.
  Future<String?> pick();
}

/// The platform's folder dialog. On Linux it goes through the desktop
/// portal, so inside a Flatpak the app gets access to the chosen folder.
final class SystemFolderPicker implements FolderPicker {
  const SystemFolderPicker();

  @override
  Future<String?> pick() => getDirectoryPath();
}

final folderPickerProvider = Provider<FolderPicker>(
  (ref) => const SystemFolderPicker(),
);
