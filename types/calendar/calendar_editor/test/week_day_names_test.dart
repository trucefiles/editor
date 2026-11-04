import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'page_harness.dart';

void main() {
  testWidgets('the month view names days as long as they fit, never '
      'broken', (tester) async {
    await pumpPage(
      tester,
      calendarPart(newCalendarText('Home')),
      today: DateTime(2026, 11, 4),
    );
    tester.view.physicalSize = const Size(1400, 800);
    await tester.pumpAndSettle();
    expect(find.text('Wednesday'), findsOne, reason: 'wide');

    tester.view.physicalSize = const Size(800, 800);
    await tester.pumpAndSettle();
    expect(find.text('Wednesday'), findsNothing, reason: 'one form for all');
    expect(find.text('Mon'), findsOne);

    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    expect(find.text('Wednesday'), findsNothing);
    expect(find.text('Wed'), findsOne, reason: 'a phone');
    expect(find.text('Mon'), findsOne);

    tester.view.physicalSize = const Size(200, 800);
    await tester.pumpAndSettle();
    expect(find.text('Wed'), findsNothing);
    expect(find.text('W'), findsOne, reason: 'narrower still');
  });
}
