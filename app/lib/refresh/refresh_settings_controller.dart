import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/app_storage.dart';
import '../platform/change_events.dart';
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
  (ref) => platformReportsChanges,
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

  Future<void> set(RefreshSettings settings) async {
    final possible = _possible(settings);
    await ref.read(refreshSettingsStoreProvider).save(possible);
    state = AsyncData(possible);
  }

  RefreshSettings _possible(RefreshSettings settings) =>
      settings.mode == RefreshMode.live &&
          !ref.read(liveRefreshAvailableProvider)
      ? settings.copyWith(mode: RefreshMode.periodic)
      : settings;
}
