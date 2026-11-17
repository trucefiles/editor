import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';

import '../alerts/alert_tap.dart';

/// The system's notifications, as alerts use them: one plugin for the
/// app, ready once [ready] completes; what the user taps comes back as
/// [taps], or as [launch] if a tap started the app.
final class AlertNotifications implements AlertTaps {
  AlertNotifications({this._inBackground});

  /// Told the buttons tapped that don't open the app (Android), on a
  /// background isolate; a top-level function.
  final void Function(NotificationResponse)? _inBackground;

  final plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<AlertTap>.broadcast();

  /// Completes once the plugin is set up.
  late final Future<void> ready = _setUp();

  @override
  Stream<AlertTap> get taps => _taps.stream;

  @override
  Future<AlertTap?> launch() async {
    await ready;
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return AlertTap.fromPayload(details.notificationResponse?.payload);
  }

  Future<void> _setUp() => plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_alert'),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    ),
    onDidReceiveNotificationResponse: (response) {
      if (AlertTap.fromPayload(response.payload) case final tap?) {
        _taps.add(tap);
      }
    },
    onDidReceiveBackgroundNotificationResponse: _inBackground,
  );

  Future<void> dispose() => _taps.close();
}

/// The number a missed alert shows under: the same for the same alert,
/// apart from the numbers alerts are planned under (which count up from
/// one), so it never replaces another's.
int missedNumberOf(PlannedAlert alert) {
  // FNV-1a over the id, as Dart's own string hashes may differ per run.
  final hash = alert.id.codeUnits.fold(
    0x811c9dc5,
    (hash, unit) => ((hash ^ unit) * 0x01000193) & 0x7fffffff,
  );
  return -1 - hash;
}
