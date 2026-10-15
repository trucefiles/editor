import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../storage/json_file.dart';
import 'refresh_settings.dart';

/// Keeps the refresh setting in a JSON file in app storage. Per device.
/// Read failures fall back to [RefreshSettings.standard].
final class RefreshSettingsStore {
  RefreshSettingsStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The saved setting; the standard one if none or unreadable.
  Future<RefreshSettings> load() async => switch (await _file.read()) {
    Ok(:final value) =>
      RefreshSettings.fromJson(value) ?? RefreshSettings.standard,
    Err() => RefreshSettings.standard,
  };

  /// Replaces the saved setting; on failure it stays as it is for this run.
  Future<void> save(RefreshSettings settings) => _file.write(settings.toJson());
}
