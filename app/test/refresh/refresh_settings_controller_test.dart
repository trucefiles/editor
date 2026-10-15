import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/refresh/refresh_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';

void main() {
  ProviderContainer start({required bool liveAvailable}) {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        liveRefreshAvailableProvider.overrideWithValue(liveAvailable),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('saves the new setting', () async {
    final container = start(liveAvailable: true);
    await container.read(refreshSettingsProvider.future);
    const periodic = RefreshSettings(
      mode: RefreshMode.periodic,
      interval: Duration(seconds: 5),
    );

    await container.read(refreshSettingsProvider.notifier).set(periodic);

    expect(await container.read(refreshSettingsStoreProvider).load(), periodic);
    expect(container.read(refreshSettingsProvider).value, periodic);
  });

  test('live counts as periodic where it is never possible', () async {
    final container = start(liveAvailable: false);

    final settings = await container.read(refreshSettingsProvider.future);

    expect(settings.mode, RefreshMode.periodic);
    expect(settings.interval, RefreshSettings.standard.interval);
  });
}
