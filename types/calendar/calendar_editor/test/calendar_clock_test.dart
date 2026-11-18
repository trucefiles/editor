import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar_editor/src/calendar_clock.dart';

void main() {
  testWidgets('tells each whole minute while listened to, and wakes for '
      'nothing after', (tester) async {
    var now = DateTime(2026, 11, 10, 9, 0, 30);
    final clock = CalendarClock(() => now, deviceZone: () => 'CET');
    final told = <DateTime>[];
    final minutes = clock.minutes.listen(told.add);

    Future<void> pass(Duration time) async {
      now = now.add(time);
      await tester.pump(time);
    }

    await pass(const Duration(seconds: 30));
    await pass(const Duration(minutes: 1));
    expect(told, [DateTime(2026, 11, 10, 9, 1), DateTime(2026, 11, 10, 9, 2)]);

    unawaited(minutes.cancel());
    await pass(const Duration(minutes: 5));
    expect(told, hasLength(2));
    clock.dispose();
  });

  testWidgets('a zone change is told within a minute', (tester) async {
    var zone = 'CET';
    final clock = CalendarClock(
      () => DateTime(2026, 11, 10, 12),
      deviceZone: () => zone,
    );
    var changes = 0;
    clock.addListener(() => changes++);

    await tester.pump(const Duration(minutes: 1));
    expect(changes, 0, reason: 'nothing changed');
    zone = 'JST';
    await tester.pump(const Duration(minutes: 1));

    expect((clock.zone, changes), ('JST', 1));
    clock.dispose();
  });

  testWidgets('the app back in front checks the zone and the day at once', (
    tester,
  ) async {
    var (now, zone) = (DateTime(2026, 11, 10, 22), 'CET');
    final clock = CalendarClock(() => now, deviceZone: () => zone);
    var changes = 0;
    clock.addListener(() => changes++);

    (now, zone) = (DateTime(2026, 11, 11, 7), 'JST');
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }

    expect(
      (clock.today, clock.zone, changes),
      (DateTime(2026, 11, 11), 'JST', 1),
    );
    clock.dispose();
  });

  testWidgets('without listeners it wakes for nothing and answers fresh', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 10, 22);
    final clock = CalendarClock(() => now, deviceZone: () => 'CET');
    void listen() {}
    clock
      ..addListener(listen)
      ..removeListener(listen);
    now = DateTime(2026, 11, 11, 7);

    expect(clock.today, DateTime(2026, 11, 11));
    // No timer is left pending: the test would fail if one were.
    clock.dispose();
  });
}
