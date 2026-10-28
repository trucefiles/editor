import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/refresh/refresh_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';

void main() {
  ProviderContainer start() {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('saves the new setting', () async {
    final container = start();
    await container.read(refreshSettingsProvider.future);
    const periodic = RefreshSettings(
      mode: RefreshMode.periodic,
      interval: Duration(seconds: 5),
    );

    await container.read(refreshSettingsProvider.notifier).set(periodic);

    expect(await container.read(refreshSettingsStoreProvider).load(), periodic);
    expect(container.read(refreshSettingsProvider).value, periodic);
  });

  test('shows the new setting while it is saved', () async {
    final container = start();
    await container.read(refreshSettingsProvider.future);
    const manual = RefreshSettings(
      mode: RefreshMode.manual,
      interval: Duration(seconds: 5),
    );

    final saving = container.read(refreshSettingsProvider.notifier).set(manual);

    expect(container.read(refreshSettingsProvider).value, manual);
    await saving;
  });

  test('keeps live on every platform', () async {
    final container = start();
    await container.read(refreshSettingsProvider.future);
    const live = RefreshSettings(
      mode: RefreshMode.live,
      interval: Duration(seconds: 5),
    );

    await container.read(refreshSettingsProvider.notifier).set(live);

    expect(await container.read(refreshSettingsProvider.future), live);
  });
}
