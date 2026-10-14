import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truce_editor/tray/native_tray_icon.dart';

/// The real tray icon on the session bus, seen the way a desktop's tray
/// sees it (StatusNotifierItem with a dbusmenu).
///
/// Needs a session bus; in CI under `dbus-run-session`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DBusClient desktop;

  setUp(() {
    desktop = DBusClient.session();
    addTearDown(desktop.close);
  });

  Future<String> trayItem() async {
    final prefix = 'org.kde.StatusNotifierItem-$pid-';
    for (var i = 0; i < 100; i++) {
      final names = await desktop.listNames();
      final item = names.where((name) => name.startsWith(prefix));
      if (item.isNotEmpty) return item.first;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('No tray item on the session bus');
  }

  testWidgets('a click on the icon opens the Open and Quit menu', (_) async {
    var opened = false;
    final dispose = nativeTrayIcon(
      iconAsset: 'linux/flatpak/io.github.trucefiles.editor-128.png',
      tooltip: 'Truce Editor',
    )(onOpen: () => opened = true, onQuit: () {});
    addTearDown(() => dispose?.call());

    final item = DBusRemoteObject(
      desktop,
      name: await trayItem(),
      path: DBusObjectPath('/StatusNotifierItem'),
    );
    const sni = 'org.kde.StatusNotifierItem';
    expect(await item.getProperty(sni, 'ItemIsMenu'), const DBusBoolean(true));
    final menuPath = await item.getProperty(sni, 'Menu') as DBusObjectPath;
    expect(menuPath.value, isNot('/'));

    final menu = DBusRemoteObject(desktop, name: item.name, path: menuPath);
    const dbusmenu = 'com.canonical.dbusmenu';
    final layout = await menu.callMethod(dbusmenu, 'GetLayout', [
      const DBusInt32(0),
      const DBusInt32(-1),
      DBusArray.string([]),
    ]);
    final entries = {
      for (final child
          in (layout.values[1] as DBusStruct).children[2].asArray())
        _label(child): (child.asVariant() as DBusStruct).children[0].asInt32(),
    };
    expect(entries.keys, ['Open', 'Quit']);

    await menu.callMethod(dbusmenu, 'Event', [
      DBusInt32(entries['Open']!),
      const DBusString('clicked'),
      const DBusVariant(DBusString('')),
      const DBusUint32(0),
    ]);
    for (var i = 0; i < 100 && !opened; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(opened, isTrue);
  });
}

String _label(DBusValue child) {
  final properties = (child.asVariant() as DBusStruct).children[1];
  return properties.asStringVariantDict()['label']!.asString();
}
