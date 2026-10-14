import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_window.dart';
import 'gtk_app_window.dart';
import 'hosted_tray.dart';
import 'linux/status_notifier_host.dart';
import 'native_tray_icon.dart';
import 'system_tray.dart';

/// The system tray of this platform; `null` where the app has none.
final systemTrayProvider = Provider<SystemTray?>(
  (ref) => Platform.isLinux
      ? HostedTray(
          host: StatusNotifierHost(),
          showIcon: nativeTrayIcon(
            iconAsset: 'linux/flatpak/io.github.trucefiles.editor-128.png',
            tooltip: 'Truce Editor',
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
