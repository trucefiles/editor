import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import '../system_tray.dart';
import '../tray_icon.dart';
import 'dbus_menu.dart';
import 'status_notifier_item.dart';

/// A [SystemTray] on Linux desktops: a StatusNotifierItem on the session
/// bus, handed to the desktop's StatusNotifierWatcher. No native code.
final class DBusTray implements SystemTray {
  DBusTray({
    required this.id,
    required this.title,
    required this.loadIcon,
    this.connect = DBusClient.session,
  });

  static const _watcher = 'org.kde.StatusNotifierWatcher';

  /// Stable name of the app, e.g. its app id.
  final String id;
  final String title;
  final Future<TrayIcon> Function() loadIcon;

  /// Opens the session bus; a test bus in tests.
  final DBusClient Function() connect;

  final _visible = ValueNotifier(false);
  DBusClient? _bus;
  StreamSubscription<DBusNameOwnerChangedEvent>? _watcherChanges;

  @override
  ValueListenable<bool> get visible => _visible;

  @override
  Future<void> show({
    required VoidCallback onOpen,
    required VoidCallback onQuit,
  }) async {
    if (_bus != null) return;
    final bus = _bus = connect();
    try {
      await bus.registerObject(
        DBusMenu([
          TrayMenuEntry('Open', onOpen),
          TrayMenuEntry('Quit', onQuit),
        ]),
      );
      await bus.registerObject(
        StatusNotifierItem(
          id: id,
          title: title,
          icon: await loadIcon(),
          menu: DBusMenu.objectPath,
          onActivate: onOpen,
        ),
      );
      // A tray that (re)starts later gets the item too.
      _watcherChanges = bus.nameOwnerChanged
          .where((change) => change.name == _watcher)
          .listen((change) {
            if (change.newOwner == null) {
              _visible.value = false;
            } else {
              unawaited(_register(bus));
            }
          });
      await _register(bus);
    } on Exception {
      // No session bus to talk to: no tray either.
      await hide();
    }
  }

  /// Hands the item to the tray; visible once the tray takes it.
  Future<void> _register(DBusClient bus) async {
    try {
      await bus.callMethod(
        destination: _watcher,
        path: DBusObjectPath('/StatusNotifierWatcher'),
        interface: _watcher,
        name: 'RegisterStatusNotifierItem',
        values: [DBusString(bus.uniqueName)],
        replySignature: DBusSignature.empty,
      );
      if (_bus == bus) _visible.value = true;
    } on DBusMethodResponseException {
      // No tray running (yet).
      if (_bus == bus) _visible.value = false;
    }
  }

  @override
  Future<void> hide() async {
    final bus = _bus;
    _bus = null;
    _visible.value = false;
    await _watcherChanges?.cancel();
    _watcherChanges = null;
    await bus?.close();
  }
}
