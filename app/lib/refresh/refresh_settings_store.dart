import 'dart:convert';
import 'dart:io';

import 'refresh_settings.dart';

/// Keeps the refresh setting in a JSON file in app storage. Per device.
/// Read failures fall back to [RefreshSettings.standard].
final class RefreshSettingsStore {
  const RefreshSettingsStore(this._file);

  final File _file;

  /// The saved setting; the standard one if none or unreadable.
  Future<RefreshSettings> load() async {
    try {
      if (!await _file.exists()) return RefreshSettings.standard;
      return RefreshSettings.fromJson(jsonDecode(await _file.readAsString())) ??
          RefreshSettings.standard;
    } on FileSystemException {
      return RefreshSettings.standard;
    } on FormatException {
      return RefreshSettings.standard;
    }
  }

  /// Replaces the saved setting atomically, via a temp file.
  Future<void> save(RefreshSettings settings) async {
    final temp = File('${_file.path}.tmp');
    try {
      await _file.parent.create(recursive: true);
      await temp.writeAsString(jsonEncode(settings.toJson()), flush: true);
      await temp.rename(_file.path);
    } on FileSystemException {
      // The setting stays as it is for this run.
    }
  }
}
