import 'dart:convert';
import 'dart:io';

/// Keeps the "keep running in the tray" setting in a JSON file in app
/// storage. Per device. On unless the user turned it off; read and write
/// failures fall back to that.
final class CloseToTrayStore {
  const CloseToTrayStore(this._file);

  final File _file;

  static const _key = 'closeToTray';

  /// The saved setting; on if none or unreadable.
  Future<bool> load() async {
    try {
      if (!await _file.exists()) return true;
      return switch (jsonDecode(await _file.readAsString())) {
        {_key: final bool enabled} => enabled,
        _ => true,
      };
    } on FileSystemException {
      return true;
    } on FormatException {
      return true;
    }
  }

  /// Replaces the saved setting atomically, via a temp file.
  Future<void> save({required bool enabled}) async {
    final temp = File('${_file.path}.tmp');
    try {
      await _file.parent.create(recursive: true);
      await temp.writeAsString(jsonEncode({_key: enabled}), flush: true);
      await temp.rename(_file.path);
    } on FileSystemException {
      // The setting stays as it is for this run.
    }
  }
}
