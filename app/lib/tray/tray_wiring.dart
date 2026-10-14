import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_window.dart';
import 'dbus/dbus_tray.dart';
import 'gtk_app_window.dart';
import 'system_tray.dart';
import 'tray_icon.dart';

/// The system tray of this platform; `null` where the app has none.
final systemTrayProvider = Provider<SystemTray?>(
  (ref) => Platform.isLinux
      ? DBusTray(
          id: 'io.github.trucefiles.editor',
          title: 'Truce Editor',
          loadIcon: () => TrayIcon.load(
            'linux/flatpak/io.github.trucefiles.editor-128.png',
          ),
        )
      : null,
);

/// The main window; only on platforms with a [systemTrayProvider].
final appWindowProvider = Provider<AppWindow>(
  (ref) => Platform.isLinux
      ? const GtkAppWindow()
      : throw UnsupportedError('No app window control on this platform'),
);
