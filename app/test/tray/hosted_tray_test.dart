import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/tray/hosted_tray.dart';
import 'package:truce_editor/tray/tray_host.dart';

final class _Host implements TrayHost {
  @override
  final ValueNotifier<bool> present = ValueNotifier(false);

  bool watching = false;

  @override
  Future<void> watch() async => watching = true;

  @override
  Future<void> stop() async => watching = false;
}

void main() {
  late _Host host;
  late HostedTray tray;
  late int icons;
  var opened = 0;
  var quit = 0;
  var created = 0;

  setUp(() {
    host = _Host();
    icons = 0;
    created = 0;
    opened = 0;
    quit = 0;
    tray = HostedTray(
      host: host,
      showIcon: ({required onOpen, required onQuit}) {
        icons++;
        created++;
        onOpen();
        onQuit();
        return () => icons--;
      },
    );
  });

  test('shows the icon while a tray is there', () async {
    host.present.value = true;

    await tray.show(onOpen: () => opened++, onQuit: () => quit++);

    expect(host.watching, isTrue);
    expect(icons, 1);
    expect(tray.visible.value, isTrue);
    expect((opened, quit), (1, 1));
  });

  test('waits for a tray, and shows the icon anew when it restarts', () async {
    await tray.show(onOpen: () {}, onQuit: () {});
    expect(icons, 0);
    expect(tray.visible.value, isFalse);

    host.present.value = true;
    expect(icons, 1);
    expect(tray.visible.value, isTrue);

    host.present.value = false;
    expect(icons, 0);
    expect(tray.visible.value, isFalse);

    host.present.value = true;
    expect(icons, 1);
    expect(created, 2);
  });

  test('hide removes the icon and stops watching', () async {
    host.present.value = true;
    await tray.show(onOpen: () {}, onQuit: () {});

    await tray.hide();

    expect(icons, 0);
    expect(host.watching, isFalse);
    expect(tray.visible.value, isFalse);
  });

  test('is not visible when the icon cannot be created', () async {
    host.present.value = true;
    final failing = HostedTray(
      host: host,
      showIcon: ({required onOpen, required onQuit}) => null,
    );

    await failing.show(onOpen: () {}, onQuit: () {});

    expect(failing.visible.value, isFalse);
  });
}
