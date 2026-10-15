import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/linux/document_portal_paths.dart';

void main() {
  late DBusServer server;
  late DBusAddress address;

  setUp(() async {
    server = DBusServer();
    address = await server.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    addTearDown(server.close);
  });

  /// Runs a Documents portal with [hostPaths] by document id.
  Future<void> runPortal({
    Map<String, String> hostPaths = const {},
    bool tellsHostPaths = true,
  }) async {
    final desktop = DBusClient(address);
    addTearDown(desktop.close);
    await desktop.requestName('org.freedesktop.portal.Documents');
    await desktop.registerObject(
      _FakePortal(hostPaths, tellsHostPaths: tellsHostPaths),
    );
  }

  DocumentPortalPaths paths() =>
      DocumentPortalPaths(connect: () => DBusClient(address));

  test('tells the host path of a folder picked through the portal', () async {
    await runPortal(hostPaths: {'ab12': '/home/me/Notes'});

    expect(await paths().of('/run/doc/ab12/Notes'), '/home/me/Notes');
    expect(await paths().of('/run/doc/ab12/Notes/work'), '/home/me/Notes/work');
  });

  test('keeps other paths', () async {
    await runPortal(hostPaths: {'ab12': '/home/me/Notes'});

    expect(await paths().of('/home/me/Notes'), '/home/me/Notes');
    expect(await paths().of('/run/doc/ab12'), '/run/doc/ab12');
    expect(await paths().of('/run/doc/cd34/Work'), '/run/doc/cd34/Work');
  });

  test('keeps paths without a portal or with an older one', () async {
    expect(await paths().of('/run/doc/ab12/Notes'), '/run/doc/ab12/Notes');

    await runPortal(tellsHostPaths: false);
    expect(await paths().of('/run/doc/ab12/Notes'), '/run/doc/ab12/Notes');
  });
}

/// The Documents portal, mounted at `/run/doc`.
final class _FakePortal extends DBusObject {
  _FakePortal(this._hostPaths, {required this.tellsHostPaths})
    : super(DBusObjectPath('/org/freedesktop/portal/documents'));

  final Map<String, String> _hostPaths;

  /// Portals before version 5 lack `GetHostPaths`.
  final bool tellsHostPaths;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface != 'org.freedesktop.portal.Documents') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (call.name) {
      case 'GetMountPoint':
        return DBusMethodSuccessResponse([_bytes('/run/doc')]);
      case 'GetHostPaths' when tellsHostPaths:
        final ids = call.values.single.asStringArray();
        return DBusMethodSuccessResponse([
          DBusDict(DBusSignature('s'), DBusSignature('ay'), {
            for (final id in ids)
              if (_hostPaths[id] case final path?) DBusString(id): _bytes(path),
          }),
        ]);
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  /// A path as the portal sends it: bytes ending in a zero byte.
  static DBusArray _bytes(String path) =>
      DBusArray.byte([...utf8.encode(path), 0]);
}
