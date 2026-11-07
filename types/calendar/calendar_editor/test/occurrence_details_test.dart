import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/ui/calendar_dot.dart';
import 'package:truce_calendar_editor/src/ui/occurrence_details.dart';

/// The one occurrence of an all-day event "Gym" of [color] on 3 November
/// 2026.
Occurrence _gym({EventColor? color}) {
  final day = DateTime(2026, 11, 3);
  final calendar = applyEdit(
    Calendar.read(newCalendarText('Home'))!,
    AddEvent(
      'a',
      EventDraft(
        summary: 'Gym',
        start: AllDay(day),
        end: AllDay(day.add(const Duration(days: 1))),
        color: color,
      ),
      at: DateTime.utc(2026, 11),
    ),
  );
  return occurrences(calendar, day, DateTime(2026, 11, 4)).single;
}

void main() {
  Future<void> show(WidgetTester tester, Occurrence occurrence) =>
      tester.pumpWidget(
        MaterialApp(home: Scaffold(body: OccurrenceDetails(occurrence))),
      );

  testWidgets('an event with its own color shows a dot of it before its '
      'title', (tester) async {
    await show(tester, _gym(color: const EventColor('red')));
    final dot = find.byType(CalendarDot);
    expect(tester.widget<CalendarDot>(dot).color, const Color(0xFFFF0000));
    expect(
      tester.getCenter(dot).dx,
      lessThan(tester.getTopLeft(find.text('Gym')).dx),
    );
  });

  testWidgets('an event without its own color shows no dot', (tester) async {
    await show(tester, _gym());
    expect(find.text('Gym'), findsOneWidget);
    expect(find.byType(CalendarDot), findsNothing);
  });
}
