import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_images/truce_images.dart' show ImagePicking, ImageSource;

import '../alerts/alarm_controls.dart';
import '../alerts/alert_permissions.dart';
import '../alerts/alert_tap.dart';
import '../alerts/planner_role.dart';
import '../app_end/app_end_source.dart';
import '../calendar_tab/calendar_clock.dart';
import '../common/time_texts.dart';
import '../settings/followed_setting.dart';
import '../tray/app_window.dart';
import '../tray/hosted_tray.dart';
import '../tray/login_start.dart';
import '../tray/native_tray_icon.dart';
import '../tray/system_tray.dart';
import 'alert_notifications.dart';
import 'android/alert_buttons.dart';
import 'android/alert_check_job.dart';
import 'android/android_alarm_controls.dart';
import 'android/android_alert_permissions.dart';
import 'android/android_ringer.dart';
import 'android/android_storage_access.dart';
import 'android/isolate_planner_role.dart';
import 'device_zone.dart';
import 'image_picking.dart';
import 'linux/background_portal.dart';
import 'linux/desktop_notices.dart';
import 'linux/document_portal.dart';
import 'linux/document_portal_paths.dart';
import 'linux/gtk_app_window.dart';
import 'linux/gtk_session_end.dart';
import 'linux/linux_ringer.dart';
import 'linux/linux_zone.dart';
import 'linux/status_notifier_host.dart';
import 'stop_signal.dart';
import 'storage_access.dart';

// The one place that tells platforms apart: it picks each platform's
// implementations and states its facts; the rest of the app sees only
// their interfaces.

/// Whether this platform tells the app about changes other apps make to
/// files as they happen: only where package:watcher has a native watcher;
/// elsewhere, as on Android, it only polls.
final _reportsChanges =
    FileSystemEntity.isWatchSupported &&
    (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

/// The local-disk service, with this platform's facts, for the plugins
/// with folders on this device. One for the app: it holds the areas they
/// claim.
final localDiskProvider = Provider<LocalDisk>(
  (ref) => LocalDisk(
    // On Android shared storage, a renamed-over file soon shows other apps
    // the old file's modification time.
    replacesInPlace: Platform.isAndroid,
    // A folder handed in through the Flatpak document portal passes on no
    // change events for changes made outside the sandbox, and shows only
    // the picked folder, not what lies above it.
    followsLive: (path) => _reportsChanges && !isInDocumentPortal(path),
    seesParents: (path) => !isInDocumentPortal(path),
    hostPaths: Platform.isLinux ? DocumentPortalPaths() : const SameHostPaths(),
  ),
);

/// Whether the app may open folders by path.
final storageAccessProvider = Provider<StorageAccess>(
  (ref) => Platform.isAndroid
      ? const AndroidStorageAccess()
      : const GrantedStorageAccess(),
);

/// Tells this device's time zone, for new calendar events.
final deviceZoneProvider = Provider<Future<String?> Function()>(
  (ref) => Platform.isLinux ? linuxZone(systemZone) : systemZone,
);

/// Whether the app itself turns the mouse's back button into Back. Not on
/// Android: it already sends a system Back for that button, so the app
/// handling it too would close two screens per press.
final handlesMouseBackProvider = Provider<bool>((ref) => !Platform.isAndroid);

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

/// What tells the app it is about to be ended from outside: on Linux the
/// desktop session's end (early, where the desktop tells it) and SIGTERM.
/// Android hides the app before it ends it, which keeps the edits.
final appEndSourcesProvider = Provider<List<AppEndSource>>(
  (ref) => Platform.isLinux ? const [GtkSessionEnd(), StopSignal()] : const [],
);

/// The system's notifications, for calendar alerts; one for the app.
final alertNotificationsProvider = Provider<AlertNotifications>((ref) {
  final notifications = AlertNotifications(
    inBackground: Platform.isAndroid ? onAlertButton : null,
  );
  ref.onDispose(notifications.dispose);
  return notifications;
});

/// The calendar alerts the user taps.
final alertTapsProvider = Provider<AlertTaps>(
  (ref) => ref.watch(alertNotificationsProvider),
);

/// What rings calendar alerts here: on Android the system's scheduled
/// notifications, in the device's alert style; on Linux the calendars'
/// clock while the app runs.
final ringerProvider = Provider<Ringer>((ref) {
  final notifications = ref.watch(alertNotificationsProvider);
  // Read when shown: a new locale doesn't make a new ringer, which would
  // start the alerts anew.
  TimeTexts texts() => ref.read(timeTextsProvider);
  if (Platform.isAndroid) {
    final style = followedSetting(ref, (s) => s.alertStyle);
    return AndroidRinger(
      notifications,
      texts,
      style: () => style.value,
      now: ref.watch(calendarClockProvider).now,
    );
  }
  final ringer = LinuxRinger(
    LinuxNotices(notifications, texts),
    minutes: ref.watch(calendarClockProvider).minutes,
  );
  ref.onDispose(ringer.dispose);
  return ringer;
});

/// Who plans the alerts: on Android the app and its background check
/// take turns; elsewhere only the app plans.
final plannerRoleProvider = Provider<PlannerRole>(
  (ref) => Platform.isAndroid ? IsolatePlannerRole() : const SoleRole(),
);

/// What the system lets alerts do.
final alertPermissionsProvider = Provider<AlertPermissions>(
  (ref) => Platform.isAndroid
      ? AndroidAlertPermissions(ref.watch(alertNotificationsProvider))
      : const GrantedAlertPermissions(),
);

/// What the alarm screen does with its alarm; `null` where alerts never
/// ring as alarms.
final alarmControlsProvider = Provider<AlarmControls?>(
  (ref) => Platform.isAndroid
      ? AndroidAlarmControls(
          ref.watch(alertNotificationsProvider),
          ref.watch(timeTextsProvider),
        )
      : null,
);

/// Whether alerts can ring as a notification or as an alarm here.
final choosesAlertStyleProvider = Provider<bool>((ref) => Platform.isAndroid);

/// Starting in the tray at login; `null` where the app has no tray.
final loginStartProvider = Provider<LoginStart?>(
  (ref) => Platform.isLinux ? BackgroundPortal() : null,
);

/// Schedules the background check of alerts, where the system runs one
/// with the app closed; `null` elsewhere.
final alertCheckScheduleProvider = Provider<Future<void> Function()?>(
  (ref) => Platform.isAndroid ? scheduleAlertCheck : null,
);

/// How pictures are picked here: on Android from the photos or the
/// camera, elsewhere by a file dialog; made ready as the image settings
/// say at each pick.
final imagePickingProvider = Provider<ImagePicking>((ref) {
  final settings = followedSetting(ref, (s) => s.images);
  return PlatformImagePicking(
    sources: Platform.isAndroid
        ? const [ImageSource.gallery, ImageSource.camera]
        : const [ImageSource.file],
    read: () => settings.value,
  );
});
