import 'alert_tap.dart';

/// What the alarm screen does with the alarm it shows.
abstract interface class AlarmControls {
  /// Shows the app over the lock screen while an alarm shows, and only
  /// then.
  Future<void> showOverLock({required bool show});

  /// Stops [alarm] ringing and rings it again a while later.
  Future<void> snooze(AlertTap alarm);

  /// Stops [alarm] ringing.
  Future<void> stop(AlertTap alarm);
}
