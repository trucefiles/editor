import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar_editor/src/views/zone_checks.dart';

void main() {
  testWidgets('checks every minute and when the app returns to the front', (
    tester,
  ) async {
    var checks = 0;
    final zoneChecks = ZoneChecks(() => checks++);

    await tester.pump(const Duration(seconds: 59));
    expect(checks, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(checks, 1);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(checks, 2);

    zoneChecks.dispose();
    await tester.pump(const Duration(minutes: 5));
    expect(checks, 2);
  });
}
