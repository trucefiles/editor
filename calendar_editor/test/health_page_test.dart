import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

import 'page_harness.dart';

final _today = DateTime(2026, 11, 3);

/// The health entries [part]'s calendar holds on [_today].
List<HealthEntry?> _entries(CalendarEditorPart part) => [
  for (final event
      in healthByDay(calendarOf(part))[DateTime.utc(2026, 11, 3)] ??
          const <CalendarEvent>[])
    event.series.health,
];

/// Adds an entry of [kind] on the picked day, as the form starts it.
Future<void> _add(WidgetTester tester, String kind) async {
  await tester.tap(find.byTooltip('Add entry'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(kind).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a period entry added shows the cycle', (tester) async {
    final part = calendarPart(newCalendarText('Me', health: true));
    await pumpPage(tester, part, today: _today);
    expect(find.text('Nothing written on this day.'), findsOne);

    await _add(tester, 'Period');
    await tester.tap(find.text('heavy'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_entries(part), [const Period(PeriodFlow.heavy)]);
    expect(find.textContaining('Day 1 of the cycle'), findsOne);
  });

  testWidgets('a symptom needs its name', (tester) async {
    final part = calendarPart(newCalendarText('Me', health: true));
    await pumpPage(tester, part, today: _today);

    await _add(tester, 'Symptom');
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Symptom'), 'Cramps');
    await tester.pump();
    await tester.tap(find.text('Strong'));
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(_entries(part), [const Symptom('Cramps', level: 3)]);
  });

  testWidgets('an entry edited keeps its day; one deleted goes', (
    tester,
  ) async {
    final part = calendarPart(newCalendarText('Me', health: true));
    await pumpPage(tester, part, today: _today);
    await _add(tester, 'Note');
    await tester.enterText(find.widgetWithText(TextField, 'Note'), 'Tired');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tired'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Note'), 'Rested');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Rested'), findsOne);
    expect(_entries(part), [const HealthNote()]);

    await tester.tap(find.text('Rested'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(_entries(part), isEmpty);
  });
}
