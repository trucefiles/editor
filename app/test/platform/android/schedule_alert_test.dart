import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_editor/alerts/alert_tap.dart';
import 'package:truce_editor/common/time_texts.dart';
import 'package:truce_editor/platform/android/android_ringer.dart';

import '../../alerts/alert_samples.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<String> calls;

  setUpAll(initializeDateFormatting);

  setUp(() {
    calls = [];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // An hour ahead of the real clock, which the system checks.
  final at = DateTime.now().add(const Duration(hours: 1));
  final tap = AlertTap(
    eventAlert('Dentist', at: at),
    number: 3,
    shown: AlertShown.notification,
  );

  Future<void> schedule({required DateTime now}) => scheduleAlert(
    FlutterLocalNotificationsPlugin(),
    tap,
    at: at,
    now: now,
    texts: TimeTexts(locale: 'en', use24Hour: true),
    exact: true,
  );

  test('an alert still to come is scheduled with the system', () async {
    await schedule(now: at.subtract(const Duration(minutes: 5)));
    expect(calls, ['zonedSchedule']);
  });

  test('an alert whose time came by now rings at once', () async {
    await schedule(now: at.add(const Duration(minutes: 1)));
    expect(calls, ['show']);
  });
}
