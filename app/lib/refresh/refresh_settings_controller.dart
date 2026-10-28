import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/setting_controller.dart';
import '../storage/app_storage.dart';
import 'refresh_settings.dart';
import 'refresh_settings_store.dart';

final refreshSettingsStoreProvider = Provider<SettingStore<RefreshSettings>>(
  (ref) => RefreshSettingsStore(
    File('${ref.watch(appStorageProvider).settingsPath}/refresh.json'),
  ),
);

final refreshSettingsProvider =
    AsyncNotifierProvider<RefreshSettingsController, RefreshSettings>(
      RefreshSettingsController.new,
    );

/// The refresh setting on this device. Live works everywhere: a folder
/// whose changes can't be followed live is checked at the interval.
class RefreshSettingsController extends SettingController<RefreshSettings> {
  @override
  Provider<SettingStore<RefreshSettings>> get store =>
      refreshSettingsStoreProvider;
}
