import 'dart:convert';

import 'package:dbus/dbus.dart';

import '../host_paths.dart';

/// Linux: folders picked through the desktop portal from inside a sandbox
/// (e.g. Flatpak) show up under the Documents portal's mount point, as
/// `<mount point>/<document id>/<folder name>`. The portal tells their
/// host paths. Other paths are host paths already.
final class DocumentPortalPaths implements HostPaths {
  DocumentPortalPaths({this.connect = DBusClient.session});

  /// Opens the session bus; a test bus in tests.
  final DBusClient Function() connect;

  static const _interface = 'org.freedesktop.portal.Documents';

  @override
  Future<String> of(String path) async {
    final bus = connect();
    try {
      final portal = DBusRemoteObject(
        bus,
        name: _interface,
        path: DBusObjectPath('/org/freedesktop/portal/documents'),
      );
      final mountPoint = await _mountPoint(portal);
      if (mountPoint == null || !path.startsWith('$mountPoint/')) return path;
      if (_segmentsOf(path, from: mountPoint) case [
        final id,
        _,
        ...final inside,
      ]) {
        if (await _hostPathOf(portal, id) case final host?) {
          return [host, ...inside].join('/');
        }
      }
      return path;
    } on Exception {
      // No session bus, no portal, or one too old to tell host paths.
      return path;
    } finally {
      await bus.close();
    }
  }

  static Future<String?> _mountPoint(DBusRemoteObject portal) async {
    final reply = await portal.callMethod(
      _interface,
      'GetMountPoint',
      const [],
      replySignature: DBusSignature('ay'),
    );
    return _decode(reply.returnValues.single.asByteArray());
  }

  static Future<String?> _hostPathOf(DBusRemoteObject portal, String id) async {
    final reply = await portal.callMethod(_interface, 'GetHostPaths', [
      DBusArray.string([id]),
    ], replySignature: DBusSignature('a{say}'));
    final paths = reply.returnValues.single.asDict();
    return switch (paths[DBusString(id)]) {
      final bytes? => _decode(bytes.asByteArray()),
      null => null,
    };
  }

  static List<String> _segmentsOf(String path, {required String from}) =>
      path.substring(from.length + 1).split('/')..removeWhere((s) => s.isEmpty);

  /// A path the portal sent as bytes, ending in a zero byte; `null` if it
  /// is not UTF-8, which the app's paths always are.
  static String? _decode(Iterable<int> bytes) {
    final text = bytes.takeWhile((byte) => byte != 0).toList();
    try {
      return utf8.decode(text);
    } on FormatException {
      return null;
    }
  }
}
