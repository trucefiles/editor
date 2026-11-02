import 'file_settings.dart';
import 'listed_file.dart';

/// Where each file's settings on this device are kept: the file
/// steps read, change and forget them as files move or go.
abstract interface class FileSettingsKeeper {
  /// The settings of [file]; the defaults if none or not loaded yet.
  FileSettings settingsOf(FileKey file);

  /// Changes the settings of [file] with [change], starting from the
  /// settings the change before left.
  Future<void> edit(
    FileKey file,
    FileSettings Function(FileSettings settings) change,
  );

  /// Forgets the settings of [file], e.g. as the user deletes it.
  Future<void> forget(FileKey file);
}
