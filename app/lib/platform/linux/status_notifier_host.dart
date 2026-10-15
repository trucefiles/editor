import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import '../../tray/tray_host.dart';

/// The tray of Linux desktops: present while a StatusNotifierWatcher runs
/// on the session bus (KDE, GNOME with AppIndicator, and most others).
final class StatusNotifierHost implements TrayHost {
  StatusNotifierHost({this.connect = DBusClient.session});

  static const _watcher = 'org.kde.StatusNotifierWatcher';

  /// Opens the session bus; a test bus in tests.
  final DBusClient Function() connect;

  final _present = ValueNotifier(false);
  DBusClient? _bus;
  StreamSubscription<DBusNameOwnerChangedEvent>? _changes;

  @override
  ValueListenable<bool> get present => _present;

  @override
  Future<void> watch() async {
    if (_bus != null) return;
    final bus = _bus = connect();
    try {
      final present = await bus.nameHasOwner(_watcher);
      if (_bus != bus) return;
      _present.value = present;
      _changes = bus.nameOwnerChanged
          .where((change) => change.name == _watcher)
          .listen((change) => _present.value = change.newOwner != null);
    } on Exception {
      // No session bus: no tray either.
      await stop();
    }
  }

  @override
  Future<void> stop() async {
    final bus = _bus;
    _bus = null;
    _present.value = false;
    await _changes?.cancel();
    _changes = null;
    await bus?.close();
  }
}
