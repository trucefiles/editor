import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_editor/alerts/alert_tap.dart';
import 'package:truce_editor/platform/linux/desktop_notices.dart';
import 'package:truce_editor/platform/linux/linux_ringer.dart';

import '../../alerts/alert_samples.dart';

/// Notices that keep what they showed, as title and how.
final class _Notices implements DesktopNotices {
  final shown = <(String, AlertShown)>[];

  @override
  Future<void> show(int number, PlannedAlert alert, AlertShown how) async =>
      shown.add((alert.title, how));
}

void main() {
  late DateTime now;
  late _Notices notices;
  late LinuxRinger ringer;

  /// Starts a ringer at [start] (half a minute past 9).
  void start([DateTime? start]) {
    now = start ?? DateTime(2026, 11, 17, 9, 0, 30);
    notices = _Notices();
    ringer = LinuxRinger(notices, now: () => now);
  }

  /// Lets [time] pass, on the clock and for the timers.
  Future<void> pass(WidgetTester tester, Duration time) async {
    now = now.add(time);
    await tester.pump(time);
  }

  testWidgets('an alert shows on the minute it comes, once', (tester) async {
    start();
    final rang = <DateTime>[];
    ringer.rang.listen(rang.add);
    await ringer.apply([
      Ring(1, eventAlert('Standup', at: DateTime(2026, 11, 17, 9, 2))),
    ]);

    await pass(tester, const Duration(seconds: 30));
    expect(notices.shown, isEmpty, reason: 'at 9:01');

    await pass(tester, const Duration(minutes: 1));
    expect(notices.shown, [('Standup', AlertShown.notification)]);
    expect(rang, hasLength(1));

    await pass(tester, const Duration(minutes: 5));
    expect(notices.shown, hasLength(1));
    // Ends the next wake before the test checks for timers.
    await ringer.dispose();
  });

  testWidgets('a silenced alert shows nothing', (tester) async {
    start();
    await ringer.apply([
      Ring(1, eventAlert('Standup', at: DateTime(2026, 11, 17, 9, 2))),
    ]);
    await ringer.apply([const Silence(1)]);

    await pass(tester, const Duration(minutes: 5));
    expect(notices.shown, isEmpty);
    // Ends the next wake before the test checks for timers.
    await ringer.dispose();
  });

  testWidgets('after a sleep, an alert come meanwhile shows within a '
      'minute; one whose event ended is dropped', (tester) async {
    start();
    await ringer.apply([
      Ring(
        1,
        eventAlert(
          'Still on',
          at: DateTime(2026, 11, 17, 9, 30),
          end: DateTime(2026, 11, 17, 12),
        ),
      ),
      Ring(
        2,
        eventAlert(
          'Over',
          at: DateTime(2026, 11, 17, 9, 10),
          end: DateTime(2026, 11, 17, 9, 45),
        ),
      ),
    ]);

    // The computer slept: the clock went on, the timers didn't.
    now = DateTime(2026, 11, 17, 10);
    await tester.pump(const Duration(minutes: 1));

    expect(notices.shown, [('Still on', AlertShown.notification)]);
    // Ends the next wake before the test checks for timers.
    await ringer.dispose();
  });

  testWidgets('missed alerts show as missed', (tester) async {
    start();
    await ringer.showMissed([
      eventAlert('Dentist', at: DateTime(2026, 11, 17, 8)),
    ]);
    expect(notices.shown, [('Dentist', AlertShown.missed)]);
    // Ends the next wake before the test checks for timers.
    await ringer.dispose();
  });
}
