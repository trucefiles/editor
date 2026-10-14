import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/tray/linux/status_notifier_host.dart';

void main() {
  late DBusServer server;
  late DBusAddress address;
  late DBusClient desktop;

  setUp(() async {
    server = DBusServer();
    address = await server.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    desktop = DBusClient(address);
    addTearDown(() async {
      await desktop.close();
      await server.close();
    });
  });

  Future<StatusNotifierHost> watching() async {
    final host = StatusNotifierHost(connect: () => DBusClient(address));
    addTearDown(host.stop);
    await host.watch();
    return host;
  }

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('is present while a tray runs', () async {
    await desktop.requestName('org.kde.StatusNotifierWatcher');

    final host = await watching();

    expect(host.present.value, isTrue);
  });

  test('follows the tray starting and stopping', () async {
    final host = await watching();
    expect(host.present.value, isFalse);

    await desktop.requestName('org.kde.StatusNotifierWatcher');
    await until(() => host.present.value);
    expect(host.present.value, isTrue);

    await desktop.releaseName('org.kde.StatusNotifierWatcher');
    await until(() => !host.present.value);
    expect(host.present.value, isFalse);
  });

  test('without a session bus there is no tray', () async {
    final host = StatusNotifierHost(
      connect: () => DBusClient(
        DBusAddress.unix(path: '${Directory.systemTemp.path}/no-such-bus'),
      ),
    );

    await host.watch();

    expect(host.present.value, isFalse);
  });
}
