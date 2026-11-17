import 'dart:async';

import 'package:dbus/dbus.dart';

import '../../tray/login_start.dart';
import '../../tray/start_in_background.dart';

/// Starts the app in the tray at login through the desktop's Background
/// portal (`org.freedesktop.portal.Background`), which works inside the
/// Flatpak sandbox without access to the host: the desktop writes the
/// autostart entry, which starts the app with [backgroundFlag].
final class BackgroundPortal implements LoginStart {
  BackgroundPortal({this.connect = DBusClient.session});

  /// Opens the session bus; a test bus in tests.
  final DBusClient Function() connect;

  static const _desktop = 'org.freedesktop.portal.Desktop';
  static const _request = 'org.freedesktop.portal.Request';

  @override
  Future<bool> set({required bool start}) async {
    final bus = connect();
    try {
      final token = 'truce${DateTime.now().microsecondsSinceEpoch}';
      // Connects, so the bus has given this client its name.
      await bus.getId();
      final sender = bus.uniqueName.substring(1).replaceAll('.', '_');
      final handle = DBusObjectPath(
        '/org/freedesktop/portal/desktop/request/$sender/$token',
      );
      // Listened for before asking, so the answer can't come first.
      final answer = DBusRemoteObjectSignalStream(
        object: DBusRemoteObject(bus, name: _desktop, path: handle),
        interface: _request,
        name: 'Response',
      ).first;
      await DBusRemoteObject(
        bus,
        name: _desktop,
        path: DBusObjectPath('/org/freedesktop/portal/desktop'),
      ).callMethod('org.freedesktop.portal.Background', 'RequestBackground', [
        const DBusString(''),
        DBusDict.stringVariant({
          'handle_token': DBusString(token),
          'reason': const DBusString(
            'Calendar alerts ring while the app runs in the tray.',
          ),
          'autostart': DBusBoolean(start),
          'commandline': DBusArray.string(['truce_editor', backgroundFlag]),
        }),
      ], replySignature: DBusSignature('o'));
      final response = await answer.timeout(const Duration(minutes: 2));
      final [code, results] = response.values;
      if (code.asUint32() != 0) return false;
      return switch (results.asStringVariantDict()['autostart']) {
        final DBusBoolean agreed => agreed.value == start,
        // A desktop that doesn't say kept what was asked.
        _ => true,
      };
    } on DBusMethodResponseException {
      return false;
    } on TimeoutException {
      return false;
    } finally {
      await bus.close();
    }
  }
}
