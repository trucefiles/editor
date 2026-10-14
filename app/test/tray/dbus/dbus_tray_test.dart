import 'dart:io';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/tray/dbus/dbus_tray.dart';
import 'package:truce_editor/tray/tray_icon.dart';

/// The desktop's tray: takes items and talks to them as a panel would.
final class _Watcher extends DBusObject {
  _Watcher() : super(DBusObjectPath('/StatusNotifierWatcher'));

  final items = <String>[];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.name != 'RegisterStatusNotifierItem') {
      return DBusMethodErrorResponse.unknownMethod();
    }
    items.add(methodCall.values.single.asString());
    return DBusMethodSuccessResponse();
  }
}

void main() {
  late DBusServer server;
  late DBusAddress address;
  late DBusClient panel;
  var opened = 0;
  var quit = 0;

  setUp(() async {
    server = DBusServer();
    address = await server.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    panel = DBusClient(address);
    opened = 0;
    quit = 0;
    addTearDown(() async {
      await panel.close();
      await server.close();
    });
  });

  DBusTray tray() => DBusTray(
    id: 'test.app',
    title: 'Test App',
    loadIcon: () async =>
        TrayIcon(width: 1, height: 1, argb: Uint8List.fromList([255, 1, 2, 3])),
    connect: () => DBusClient(address),
  );

  Future<DBusTray> shown() async {
    final shown = tray();
    addTearDown(shown.hide);
    await shown.show(onOpen: () => opened++, onQuit: () => quit++);
    return shown;
  }

  Future<_Watcher> startWatcher() async {
    final watcher = _Watcher();
    await panel.requestName('org.kde.StatusNotifierWatcher');
    await panel.registerObject(watcher);
    return watcher;
  }

  DBusRemoteObject item(String name, String path) =>
      DBusRemoteObject(panel, name: name, path: DBusObjectPath(path));

  test('hands the item to the tray', () async {
    final watcher = await startWatcher();
    final tray = await shown();

    expect(tray.visible.value, isTrue);
    expect(watcher.items, hasLength(1));
    final sni = item(watcher.items.single, '/StatusNotifierItem');
    final properties = await sni.getAllProperties('org.kde.StatusNotifierItem');
    expect(properties['Id'], const DBusString('test.app'));
    expect(properties['Menu'], DBusObjectPath('/MenuBar'));
    final pixmap = (await sni.getProperty(
      'org.kde.StatusNotifierItem',
      'IconPixmap',
    )).asArray().single.asStruct();
    expect(pixmap[2].asByteArray(), [255, 1, 2, 3]);
  });

  test('is not visible without a tray, and appears once one starts', () async {
    final tray = await shown();
    expect(tray.visible.value, isFalse);

    final watcher = await startWatcher();
    await pumpEventQueue();
    for (var i = 0; i < 50 && !tray.visible.value; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(tray.visible.value, isTrue);
    expect(watcher.items, hasLength(1));
  });

  test('a click on the icon opens the app', () async {
    final watcher = await startWatcher();
    await shown();

    await item(watcher.items.single, '/StatusNotifierItem').callMethod(
      'org.kde.StatusNotifierItem',
      'Activate',
      const [DBusInt32(0), DBusInt32(0)],
      replySignature: DBusSignature.empty,
    );

    expect(opened, 1);
  });

  test('the menu has Open and Quit', () async {
    final watcher = await startWatcher();
    await shown();
    final menu = item(watcher.items.single, '/MenuBar');

    final layout = await menu.callMethod(
      'com.canonical.dbusmenu',
      'GetLayout',
      [const DBusInt32(0), const DBusInt32(-1), DBusArray.string(const [])],
      replySignature: DBusSignature('u(ia{sv}av)'),
    );
    final [_, _, children] = layout.values[1].asStruct();
    final labels = [
      for (final child in children.asVariantArray())
        child.asStruct()[1].asStringVariantDict()['label']!.asString(),
    ];
    expect(labels, ['Open', 'Quit']);

    await menu.callMethod('com.canonical.dbusmenu', 'Event', [
      const DBusInt32(2),
      const DBusString('clicked'),
      const DBusVariant(DBusString('')),
      const DBusUint32(0),
    ], replySignature: DBusSignature.empty);
    await menu.callMethod('com.canonical.dbusmenu', 'EventGroup', [
      DBusArray(DBusSignature('(isvu)'), [
        DBusStruct(const [
          DBusInt32(1),
          DBusString('clicked'),
          DBusVariant(DBusString('')),
          DBusUint32(0),
        ]),
      ]),
    ], replySignature: DBusSignature('ai'));

    expect(quit, 1);
    expect(opened, 1);
  });

  test('hide takes the item away', () async {
    await startWatcher();
    final tray = await shown();

    await tray.hide();

    expect(tray.visible.value, isFalse);
  });

  test('without a session bus there is no tray', () async {
    final noBus = DBusTray(
      id: 'test.app',
      title: 'Test App',
      loadIcon: () async => TrayIcon(width: 0, height: 0, argb: Uint8List(0)),
      connect: () => DBusClient(
        DBusAddress.unix(path: '${Directory.systemTemp.path}/no-such-bus'),
      ),
    );

    await noBus.show(onOpen: () {}, onQuit: () {});

    expect(noBus.visible.value, isFalse);
  });
}
