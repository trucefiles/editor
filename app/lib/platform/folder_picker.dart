import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

/// Asks the user for a folder on this device.
abstract interface class FolderPicker {
  /// The address of the chosen folder (`file:`); `null` if the user
  /// cancelled.
  Future<Result<Uri?, PickError>> pick();
}

enum PickError {
  /// The folder has no path the app can open, e.g. on an SD card or in a
  /// cloud app on Android.
  unsupportedLocation,
}

/// The platform's folder dialog. On Linux it goes through the desktop
/// portal, so inside a Flatpak the app gets access to the chosen folder.
/// On Android it returns a path on the device's main storage.
final class SystemFolderPicker implements FolderPicker {
  const SystemFolderPicker();

  @override
  Future<Result<Uri?, PickError>> pick() async {
    try {
      return Ok(switch (await getDirectoryPath()) {
        final path? => Uri.file(path),
        null => null,
      });
    } on PlatformException {
      return const Err(PickError.unsupportedLocation);
    }
  }
}

final folderPickerProvider = Provider<FolderPicker>(
  (ref) => const SystemFolderPicker(),
);
