import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/tray/close_to_tray_controller.dart';

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

  ProviderContainer container({bool withTray = true}) {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        systemTrayProvider.overrideWithValue(withTray ? tray : null),
        appWindowProvider.overrideWithValue(window),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('by default, shows the icon and hides the window on close', () async {
    final state = await container().read(closeToTrayProvider.future);

    expect(state.enabled, isTrue);
    expect(tray.shown, isTrue);
    expect(window.hideOnClose, isTrue);
  });

  test('quits on close while no tray shows the icon', () async {
    tray.hasTray = false;
    final state = await container().read(closeToTrayProvider.future);

    expect(state.enabled, isTrue);
    expect(state.hidesOnClose, isFalse);
    expect(window.hideOnClose, isFalse);
  });

  test('follows the tray coming and going', () async {
    tray.hasTray = false;
    final app = container();
    await app.read(closeToTrayProvider.future);

    tray.visible.value = true;
    await pumpEventQueue();
    expect(window.hideOnClose, isTrue);
    expect(app.read(closeToTrayProvider).value!.trayVisible, isTrue);

    tray.visible.value = false;
    await pumpEventQueue();
    expect(window.hideOnClose, isFalse);
  });

  test('turning it off removes the icon and quits on close', () async {
    final app = container();
    await app.read(closeToTrayProvider.future);

    await app.read(closeToTrayProvider.notifier).setEnabled(enabled: false);

    expect(app.read(closeToTrayProvider).value!.enabled, isFalse);
    expect(tray.shown, isFalse);
    expect(window.hideOnClose, isFalse);
  });

  test('shows the setting while the tray follows', () async {
    final app = container();
    await app.read(closeToTrayProvider.future);

    final changing = app
        .read(closeToTrayProvider.notifier)
        .setEnabled(enabled: false);

    expect(app.read(closeToTrayProvider).value!.enabled, isFalse);
    await changing;
    expect(tray.shown, isFalse);
  });

  test('changes made at once end as the last one says', () async {
    final app = container();
    await app.read(closeToTrayProvider.future);
    final controller = app.read(closeToTrayProvider.notifier);

    await Future.wait([
      controller.setEnabled(enabled: false),
      controller.setEnabled(enabled: true),
    ]);

    expect(app.read(closeToTrayProvider).value!.enabled, isTrue);
    expect(tray.shown, isTrue);
    expect(window.hideOnClose, isTrue);
  });

  test('remembers the setting across starts', () async {
    final first = container();
    await first.read(closeToTrayProvider.future);
    await first.read(closeToTrayProvider.notifier).setEnabled(enabled: false);
    first.dispose();

    final state = await container().read(closeToTrayProvider.future);

    expect(state.enabled, isFalse);
    expect(tray.shown, isFalse);
  });

  test('the menu opens and quits through the window', () async {
    await container().read(closeToTrayProvider.future);

    tray.onOpen!();
    tray.onQuit!();
    await pumpEventQueue();

    expect(window.shows, 1);
    expect(window.quits, 1);
  });

  test('does nothing where the platform has no tray', () async {
    final state = await container(withTray: false)
        .read(closeToTrayProvider.future);

    expect(state.enabled, isFalse);
    expect(window.hideOnClose, isFalse);
  });
}
