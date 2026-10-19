import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/tray/close_to_tray_controller.dart';
import 'package:truce_editor/tray/start_in_background.dart';

import '../support.dart';
import 'fakes.dart';

void main() {
  late FakeTray tray;
  late FakeWindow window;
  late AppStorage storage;

  setUp(() {
    tray = FakeTray();
    window = FakeWindow();
    storage = AppStorage(tempFolder().path);
  });

  ProviderContainer container({bool background = true, bool withTray = true}) {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        systemTrayProvider.overrideWithValue(withTray ? tray : null),
        appWindowProvider.overrideWithValue(window),
        startInBackgroundProvider.overrideWithValue(background),
        trayStartWaitProvider.overrideWithValue(
          const Duration(milliseconds: 50),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('stays hidden while the app runs in the tray', () async {
    await container().read(backgroundStartProvider.future);

    expect(window.shows, 0);
  });

  test('shows the window with the tray setting off', () async {
    final app = container();
    await app.read(closeToTrayProvider.future);
    await app.read(closeToTrayProvider.notifier).setEnabled(enabled: false);

    await app.read(backgroundStartProvider.future);

    expect(window.shows, 1);
  });

  test('waits for a tray that is still starting', () async {
    tray.hasTray = false;
    final app = container();
    await app.read(closeToTrayProvider.future);

    final start = app.read(backgroundStartProvider.future);
    tray.visible.value = true;
    await start;

    expect(window.shows, 0);
  });

  test('shows the window when no tray comes', () async {
    tray.hasTray = false;

    await container().read(backgroundStartProvider.future);

    expect(window.shows, 1);
  });

  test('does nothing on a normal start', () async {
    await container(background: false).read(backgroundStartProvider.future);

    expect(window.shows, 0);
  });
}
