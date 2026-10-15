import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tray/app_window.dart';
import '../tray/hosted_tray.dart';
import '../tray/native_tray_icon.dart';
import '../tray/system_tray.dart';
import 'android/android_storage_access.dart';
import 'host_paths.dart';
import 'linux/document_portal.dart';
import 'linux/document_portal_paths.dart';
import 'linux/gtk_app_window.dart';
import 'linux/status_notifier_host.dart';
import 'platform_facts.dart';
import 'storage_access.dart';

// The one place that tells platforms apart: it picks each platform's
// implementations and states its facts; the rest of the app sees only
// their interfaces.

/// Facts about this platform, for the sync-tool wiring and settings.
final platformFactsProvider = Provider<PlatformFacts>(
  (ref) => PlatformFacts(
    // Only where package:watcher has a native watcher; elsewhere, as on
    // Android, it only polls.
    reportsChanges:
        FileSystemEntity.isWatchSupported &&
        (Platform.isLinux || Platform.isMacOS || Platform.isWindows),
    // On Android shared storage, a renamed-over file soon shows other apps
    // the old file's modification time.
    replacesInPlace: Platform.isAndroid,
    isPortalFolder: isInDocumentPortal,
  ),
);

/// Whether the app may open folders by path.
final storageAccessProvider = Provider<StorageAccess>(
  (ref) => Platform.isAndroid
      ? const AndroidStorageAccess()
      : const GrantedStorageAccess(),
);

/// Where folders lie on the host system.
final hostPathsProvider = Provider<HostPaths>(
  (ref) => Platform.isLinux ? DocumentPortalPaths() : const SameHostPaths(),
);

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
