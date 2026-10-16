import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/platform_wiring.dart';
import '../storage/app_storage.dart';
import 'refresh_settings.dart';
import 'refresh_settings_store.dart';

final refreshSettingsStoreProvider = Provider<RefreshSettingsStore>(
  (ref) => RefreshSettingsStore(
    File('${ref.watch(appStorageProvider).settingsPath}/refresh.json'),
  ),
);

/// Whether live updates are possible anywhere on this platform; if not,
/// the user can't pick them.
final liveRefreshAvailableProvider = Provider<bool>(
  (ref) => ref.watch(platformFactsProvider).reportsChanges,
);

final refreshSettingsProvider =
    AsyncNotifierProvider<RefreshSettingsController, RefreshSettings>(
      RefreshSettingsController.new,
    );

/// The refresh setting on this device. Where live updates are never
/// possible, a live setting counts as periodic.
class RefreshSettingsController extends AsyncNotifier<RefreshSettings> {
  @override
  Future<RefreshSettings> build() async =>
      _possible(await ref.watch(refreshSettingsStoreProvider).load());

  /// Takes [settings] right away, so every screen shows them while they
  /// are saved. Saves run in order, so the last one stays.
  Future<void> set(RefreshSettings settings) {
    final possible = _possible(settings);
    state = AsyncData(possible);
    return ref.read(refreshSettingsStoreProvider).save(possible);
  }

  RefreshSettings _possible(RefreshSettings settings) =>
      settings.mode == RefreshMode.live &&
          !ref.read(liveRefreshAvailableProvider)
      ? settings.copyWith(mode: RefreshMode.periodic)
      : settings;
}
