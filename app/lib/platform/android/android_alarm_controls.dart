import 'package:flutter/services.dart';

import '../../alerts/alarm_controls.dart';
import '../../alerts/alert_tap.dart';
import '../../common/time_texts.dart';
import '../alert_notifications.dart';
import 'android_ringer.dart';

/// The alarm screen's controls on Android: the window shown over the lock
/// screen (and the screen turned on) through `MainActivity`, and the
/// alarm's notification stopped or scheduled again.
final class AndroidAlarmControls implements AlarmControls {
  const AndroidAlarmControls(this._notifications, this._texts);

  final AlertNotifications _notifications;
  final TimeTexts _texts;

  static const _window = MethodChannel(
    'io.github.trucefiles.editor/alarm_window',
  );

  @override
  Future<void> showOverLock({required bool show}) =>
      _window.invokeMethod('showOverLock', show);

  @override
  Future<void> snooze(AlertTap alarm) async {
    await stop(alarm);
    await scheduleAlert(
      _notifications.plugin,
      alarm,
      at: DateTime.now().add(snoozeFor),
      texts: _texts,
      exact: await mayRingExactly(_notifications.plugin),
    );
  }

  @override
  Future<void> stop(AlertTap alarm) async {
    await _notifications.ready;
    await _notifications.plugin.cancel(id: alarm.number);
  }
}
