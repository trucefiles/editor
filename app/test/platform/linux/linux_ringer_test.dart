import 'dart:async';

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
  late StreamController<DateTime> minutes;
  late _Notices notices;
  late LinuxRinger ringer;

  /// Starts a ringer on a clock of its own.
  void start() {
    minutes = StreamController();
    notices = _Notices();
    ringer = LinuxRinger(notices, minutes: minutes.stream);
    addTearDown(ringer.dispose);
  }

  /// The clock tells the minute [time].
  Future<void> tick(DateTime time) async {
    minutes.add(time);
    await pumpEventQueue();
  }

  test('an alert shows on the minute it comes, once', () async {
    start();
    final rang = <DateTime>[];
    ringer.rang.listen(rang.add);
    await ringer.apply([
      Ring(1, eventAlert('Standup', at: DateTime(2026, 11, 17, 9, 2))),
    ]);

    await tick(DateTime(2026, 11, 17, 9, 1));
    expect(notices.shown, isEmpty, reason: 'at 9:01');

    await tick(DateTime(2026, 11, 17, 9, 2));
    expect(notices.shown, [('Standup', AlertShown.notification)]);
    expect(rang, hasLength(1));

    await tick(DateTime(2026, 11, 17, 9, 3));
    expect(notices.shown, hasLength(1));
  });

  test('a silenced alert shows nothing', () async {
    start();
    await ringer.apply([
      Ring(1, eventAlert('Standup', at: DateTime(2026, 11, 17, 9, 2))),
    ]);
    await ringer.apply([const Silence(1)]);

    await tick(DateTime(2026, 11, 17, 9, 5));
    expect(notices.shown, isEmpty);
  });

  test('after a sleep, an alert come meanwhile shows within a '
      'minute; one whose event ended is dropped', () async {
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

    // The computer slept: the next minute told is 10:00.
    await tick(DateTime(2026, 11, 17, 10));

    expect(notices.shown, [('Still on', AlertShown.notification)]);
  });

  test('missed alerts show as missed', () async {
    start();
    await ringer.showMissed([
      eventAlert('Dentist', at: DateTime(2026, 11, 17, 8)),
    ]);
    expect(notices.shown, [('Dentist', AlertShown.missed)]);
  });
}
