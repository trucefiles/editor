import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';

import '../../alerts/alert_style.dart';
import '../../alerts/alert_tap.dart';
import '../../alerts/alert_texts.dart';
import '../../common/time_texts.dart';
import '../alert_notifications.dart';
import '../ring_failures.dart';

/// Rings alerts with the system's exact scheduled notifications, so they
/// ring with the app closed and after a restart (the plugin schedules
/// them again then; ones that came while the phone was off show at once).
/// Each rings in the device's [AlertStyle], as set when it was handed.
/// One the system refuses is skipped ([orSkip]).
final class AndroidRinger implements Ringer {
  AndroidRinger(
    this._notifications,
    this._texts, {
    required this._style,
    required this._now,
  });

  final AlertNotifications _notifications;
  final DateTime Function() _now;

  /// The time texts as the device writes them now.
  final TimeTexts Function() _texts;
  final AlertStyle Function() _style;

  @override
  bool get ringsWhileClosed => true;

  @override
  Stream<DateTime> get rang => const Stream.empty();

  @override
  Future<Set<int>> apply(List<RingChange> changes) async {
    await _notifications.ready;
    final shown = switch (_style()) {
      AlertStyle.notification => AlertShown.notification,
      AlertStyle.alarm => AlertShown.alarm,
    };
    final exact = await mayRingExactly(_notifications.plugin);
    final refused = <int>{};
    for (final change in changes) {
      switch (change) {
        case Ring(:final number, :final alert):
          final taken = await orSkip(
            'hand alert $number to the system',
            () => scheduleAlert(
              _notifications.plugin,
              AlertTap(alert, number: number, shown: shown),
              at: alert.at,
              now: _now(),
              texts: _texts(),
              exact: exact,
            ),
          );
          if (!taken) refused.add(number);
        case Silence(:final number):
          await orSkip(
            'take alert $number back',
            () => _notifications.plugin.cancel(id: number),
          );
      }
    }
    return refused;
  }

  @override
  Future<void> showMissed(List<PlannedAlert> missed) async {
    await _notifications.ready;
    for (final alert in missed) {
      final tap = AlertTap(
        alert,
        number: missedNumberOf(alert),
        shown: AlertShown.missed,
      );
      await orSkip(
        'show missed alert ${tap.number}',
        () => _notifications.plugin.show(
          id: tap.number,
          title: alertTitle(alert),
          body: missedWhen(alert, _texts()),
          payload: tap.payload,
          notificationDetails: notificationDetailsOf(AlertShown.missed),
        ),
      );
    }
  }
}

/// Schedules [tap]'s alert to ring at [at] as [tap] says, under its
/// number (in place of one by that number); also for a snooze. One whose
/// time came by [now], while it was handed over, rings at once. Unless [exact] (see
/// [mayRingExactly]), it rings as near [at] as the system lets it.
Future<void> scheduleAlert(
  FlutterLocalNotificationsPlugin plugin,
  AlertTap tap, {
  required DateTime at,
  required DateTime now,
  required TimeTexts texts,
  required bool exact,
}) async {
  final (title, body) = (alertTitle(tap.alert), alertWhen(tap.alert, texts));
  final details = notificationDetailsOf(tap.shown);
  // The system only takes times still ahead when it gets them.
  if (at.isBefore(now.add(const Duration(seconds: 1)))) {
    return plugin.show(
      id: tap.number,
      title: title,
      body: body,
      payload: tap.payload,
      notificationDetails: details,
    );
  }
  await plugin.zonedSchedule(
    id: tap.number,
    scheduledDate: tz.TZDateTime.from(at, tz.UTC),
    title: title,
    body: body,
    payload: tap.payload,
    notificationDetails: details,
    androidScheduleMode: exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

/// Whether alerts may ring at their exact time: not where the user took
/// exact alarms away from the app.
Future<bool> mayRingExactly(FlutterLocalNotificationsPlugin plugin) async =>
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.canScheduleExactNotifications() ??
    true;

/// The id of the button that rings an alert again a while later.
const snoozeAction = 'snooze';

/// The id of the button that stops an alert.
const dismissAction = 'dismiss';

/// How long a snooze waits.
const snoozeFor = Duration(minutes: 10);

/// How an alert shows, in its own channel per way, so the user can tune
/// each in the system settings.
NotificationDetails notificationDetailsOf(AlertShown shown) =>
    NotificationDetails(
      android: switch (shown) {
        AlertShown.notification => const AndroidNotificationDetails(
          'alerts',
          'Alerts',
          channelDescription: 'Calendar alerts that pop up with one sound',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          actions: _buttons,
        ),
        AlertShown.alarm => AndroidNotificationDetails(
          'alarms',
          'Alarms',
          channelDescription:
              'Calendar alerts that ring full screen until you stop them',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          sound: const UriAndroidNotificationSound(
            'content://settings/system/alarm_alert',
          ),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          // Rings on until the user acts (Notification.FLAG_INSISTENT).
          additionalFlags: Int32List.fromList([4]),
          actions: _buttons,
        ),
        AlertShown.missed => const AndroidNotificationDetails(
          'missed',
          'Missed alerts',
          channelDescription:
              "Calendar alerts that came while they couldn't ring",
          importance: Importance.low,
          priority: Priority.low,
          category: AndroidNotificationCategory.reminder,
        ),
      },
    );

const _buttons = [
  AndroidNotificationAction(snoozeAction, 'Snooze 10 min'),
  AndroidNotificationAction(dismissAction, 'Dismiss'),
];
