import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';

import '../../alerts/alert_tap.dart';
import '../../alerts/alert_texts.dart';
import '../../common/time_texts.dart';
import '../alert_notifications.dart';
import '../ring_failures.dart';

/// Shows an alert as a desktop notification.
abstract interface class DesktopNotices {
  /// Shows [alert] as [shown] says, under [number].
  Future<void> show(int number, PlannedAlert alert, AlertShown shown);
}

/// Desktop notifications over D-Bus (`org.freedesktop.Notifications`); a
/// missed alert shows with low urgency. One the desktop can't show (no
/// notification service) is skipped ([orSkip]).
final class LinuxNotices implements DesktopNotices {
  const LinuxNotices(this._notifications, this._texts);

  final AlertNotifications _notifications;

  /// The time texts as the device writes them now.
  final TimeTexts Function() _texts;

  @override
  Future<void> show(int number, PlannedAlert alert, AlertShown shown) async {
    await _notifications.ready;
    final missed = shown == AlertShown.missed;
    await orSkip(
      'show alert $number',
      () => _notifications.plugin.show(
        id: number,
        title: alertTitle(alert),
        body: missed ? missedWhen(alert, _texts()) : alertWhen(alert, _texts()),
        payload: AlertTap(alert, number: number, shown: shown).payload,
        notificationDetails: NotificationDetails(
          linux: LinuxNotificationDetails(
            urgency: missed
                ? LinuxNotificationUrgency.low
                : LinuxNotificationUrgency.normal,
            defaultActionName: 'Open',
          ),
        ),
      ),
    );
  }
}
