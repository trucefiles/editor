import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../storage/json_file.dart';

/// Keeps the "keep running in the tray" setting in a JSON file in app
/// storage. Per device. On unless the user turned it off; read and write
/// failures fall back to that.
final class CloseToTrayStore {
  CloseToTrayStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  static const _key = 'closeToTray';

  /// The saved setting; on if none or unreadable.
  Future<bool> load() async => switch (await _file.read()) {
    Ok(value: {_key: final bool enabled}) => enabled,
    _ => true,
  };

  /// Replaces the saved setting; on failure it stays as it is for this run.
  Future<void> save({required bool enabled}) => _file.write({_key: enabled});
}
