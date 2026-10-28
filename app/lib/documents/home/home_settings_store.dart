import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../../storage/json_file.dart';
import '../../storage/setting_store.dart';
import 'home_settings.dart';

/// Keeps the home screen's settings in a JSON file in app storage. Per
/// device. Read failures fall back to [HomeSettings.standard].
final class HomeSettingsStore implements SettingStore<HomeSettings> {
  HomeSettingsStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The saved settings; the standard ones if none or unreadable.
  @override
  Future<HomeSettings> load() async => switch (await _file.read()) {
    Ok(:final value) => HomeSettings.fromJson(value) ?? HomeSettings.standard,
    Err() => HomeSettings.standard,
  };

  /// Replaces the saved settings; on failure they stay as they are for
  /// this run.
  @override
  Future<void> save(HomeSettings settings) => _file.write(settings.toJson());
}
