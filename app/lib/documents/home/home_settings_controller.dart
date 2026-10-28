import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/setting_controller.dart';
import '../../storage/app_storage.dart';
import 'home_settings.dart';
import 'home_settings_store.dart';

final homeSettingsStoreProvider = Provider<SettingStore<HomeSettings>>(
  (ref) => HomeSettingsStore(
    File('${ref.watch(appStorageProvider).settingsPath}/home.json'),
  ),
);

final homeSettingsProvider =
    AsyncNotifierProvider<HomeSettingsController, HomeSettings>(
      HomeSettingsController.new,
    );

/// The home screen's settings on this device.
class HomeSettingsController extends SettingController<HomeSettings> {
  @override
  Provider<SettingStore<HomeSettings>> get store => homeSettingsStoreProvider;
}
