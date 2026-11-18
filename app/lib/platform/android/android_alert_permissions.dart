import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../alerts/alert_permissions.dart';
import '../alert_notifications.dart';

/// Android's permissions for alerts: notifications (asked from Android
/// 13), and full-screen alarms (asked in the system settings from
/// Android 14). Exact alarms need no asking: calendar apps may use them.
final class AndroidAlertPermissions implements AlertPermissions {
  const AndroidAlertPermissions(this._notifications);

  final AlertNotifications _notifications;

  Future<AndroidFlutterLocalNotificationsPlugin> get _android async {
    await _notifications.ready;
    return _notifications.plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
  }

  @override
  Future<bool> mayNotify() async =>
      await (await _android).areNotificationsEnabled() ?? false;

  @override
  Future<bool> askToNotify() async =>
      await (await _android).requestNotificationsPermission() ?? false;

  @override
  Future<void> askForFullScreen() async =>
      (await _android).requestFullScreenIntentPermission();
}
