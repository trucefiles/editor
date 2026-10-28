import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/platform_wiring.dart';
import '../settings/setting_controller.dart';
import '../storage/app_storage.dart';
import 'refresh_settings.dart';
import 'refresh_settings_store.dart';

final refreshSettingsStoreProvider = Provider<SettingStore<RefreshSettings>>(
  (ref) => RefreshSettingsStore(
    File('${ref.watch(appStorageProvider).settingsPath}/refresh.json'),
  ),
);

/// Whether live updates are possible anywhere on this platform; if not,
/// the user can't pick them.
final liveRefreshAvailableProvider = Provider<bool>(
  (ref) => ref.watch(liveChangesPossibleProvider),
);

final refreshSettingsProvider =
    AsyncNotifierProvider<RefreshSettingsController, RefreshSettings>(
      RefreshSettingsController.new,
    );

/// The refresh setting on this device. Where live updates are never
/// possible, a live setting counts as periodic.
class RefreshSettingsController extends SettingController<RefreshSettings> {
  @override
  Provider<SettingStore<RefreshSettings>> get store =>
      refreshSettingsStoreProvider;

  @override
  RefreshSettings fit(RefreshSettings value) =>
      value.mode == RefreshMode.live && !ref.read(liveRefreshAvailableProvider)
      ? value.copyWith(mode: RefreshMode.periodic)
      : value;
}
