import 'package:flutter/foundation.dart';
import 'package:truce_editor/tray/app_window.dart';
import 'package:truce_editor/tray/system_tray.dart';

/// A tray that is there whenever [visible] says so.
final class FakeTray implements SystemTray {
  @override
  final ValueNotifier<bool> visible = ValueNotifier(false);

  /// Whether the app asked for the icon.
  bool shown = false;
  VoidCallback? onOpen;
  VoidCallback? onQuit;

  /// Set before [show] to simulate a desktop with a tray.
  bool hasTray = true;

  @override
  Future<void> show({
    required VoidCallback onOpen,
    required VoidCallback onQuit,
  }) async {
    shown = true;
    this.onOpen = onOpen;
    this.onQuit = onQuit;
    visible.value = hasTray;
  }

  @override
  Future<void> hide() async {
    shown = false;
    visible.value = false;
  }
}

final class FakeWindow implements AppWindow {
  bool hideOnClose = false;
  int shows = 0;
  int quits = 0;

  @override
  Future<void> setHideOnClose({required bool hide}) async => hideOnClose = hide;

  @override
  Future<void> show() async => shows++;

  @override
  Future<void> quit() async => quits++;
}
