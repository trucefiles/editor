import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../alerts/alert_tap.dart';
import '../../common/device_locale.dart';
import '../../common/time_texts.dart';
import 'android_ringer.dart';

/// Handles an alert's button tapped without opening the app, on a
/// background isolate: Snooze rings the same alert again [snoozeFor]
/// later, under its number (the planner's state stays as it was);
/// Dismiss only closes it, which the system did.
@pragma('vm:entry-point')
Future<void> onAlertButton(NotificationResponse response) async {
  if (response.actionId != snoozeAction) return;
  final tap = AlertTap.fromPayload(response.payload);
  if (tap == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_alert'),
    ),
  );
  await scheduleAlert(
    plugin,
    tap,
    at: DateTime.now().add(snoozeFor),
    texts: deviceTimeTexts(
      supportedLocaleOf(PlatformDispatcher.instance.locale),
    ),
    exact: await mayRingExactly(plugin),
  );
}
