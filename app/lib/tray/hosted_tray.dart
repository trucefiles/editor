import 'package:flutter/foundation.dart';

import 'system_tray.dart';
import 'tray_host.dart';

/// Puts an icon in the tray; returns how to remove it, or `null` if it
/// could not be created.
typedef ShowTrayIcon = VoidCallback? Function({
  required VoidCallback onOpen,
  required VoidCallback onQuit,
});

/// A [SystemTray] that shows its icon while the [host] is present, and
/// shows it anew when a tray (re)starts, as trays forget icons then.
final class HostedTray implements SystemTray {
  HostedTray({required this.host, required this.showIcon});

  final TrayHost host;
  final ShowTrayIcon showIcon;

  final _visible = ValueNotifier(false);
  ({VoidCallback onOpen, VoidCallback onQuit})? _menu;
  VoidCallback? _removeIcon;

  @override
  ValueListenable<bool> get visible => _visible;

  @override
  Future<void> show({
    required VoidCallback onOpen,
    required VoidCallback onQuit,
  }) async {
    if (_menu != null) return;
    _menu = (onOpen: onOpen, onQuit: onQuit);
    host.present.addListener(_follow);
    await host.watch();
    _follow();
  }

  @override
  Future<void> hide() async {
    if (_menu == null) return;
    _menu = null;
    host.present.removeListener(_follow);
    await host.stop();
    _follow();
  }

  void _follow() {
    _removeIcon?.call();
    _removeIcon = null;
    if (_menu case final menu? when host.present.value) {
      _removeIcon = showIcon(onOpen: menu.onOpen, onQuit: menu.onQuit);
    }
    _visible.value = _removeIcon != null;
  }
}
