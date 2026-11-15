import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar_editor/src/views_clock.dart';

void main() {
  testWidgets('a zone change is told within a minute', (tester) async {
    var zone = 'CET';
    final clock = ViewsClock(
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
    final clock = ViewsClock(() => now, deviceZone: () => zone);
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
}
