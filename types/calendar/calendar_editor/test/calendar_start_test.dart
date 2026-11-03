import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'page_harness.dart';

final _today = DateTime(2026, 11, 3);

/// A calendar with "Call" on [_today] from 9 for an hour.
final _call = applyEdit(
  Calendar.read(newCalendarText('Home'))!,
  AddEvent(
    'call',
    EventDraft(
      summary: 'Call',
      start: Floating(DateTime.utc(2026, 11, 3, 9)),
      end: Floating(DateTime.utc(2026, 11, 3, 10)),
    ),
    at: editedAt,
  ),
);

final _callAt = EditOccurrence('call', null, start: DateTime(2026, 11, 3, 9));

void main() {
  testWidgets('a page asked to edit an event opens its form once it shows, '
      'once', (tester) async {
    final starts = CalendarStarts()..ask(pageFile, _callAt);
    final part = calendarPart(_call.text);
    await pumpPage(tester, part, today: _today, starts: starts);

    expect(find.text('Edit event'), findsOne);
    await tester.enterText(find.widgetWithText(TextField, 'Place'), 'Home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(calendarOf(part).events.single.series.location, 'Home');
    expect(starts.take(pageFile), isNull, reason: 'taken');
  });

  testWidgets('a health entry asked to edit opens its own form', (
    tester,
  ) async {
    final health = applyEdit(
      Calendar.read(newCalendarText('Me', health: true))!,
      AddEvent(
        'note',
        EventDraft.health(const HealthNote(), DateTime.utc(2026, 11, 3)),
        at: editedAt,
      ),
    );
    final starts = CalendarStarts()
      ..ask(
        pageFile,
        EditOccurrence('note', null, start: DateTime(2026, 11, 3)),
      );
    await pumpPage(
      tester,
      calendarPart(health.text),
      today: _today,
      starts: starts,
    );
    expect(find.text('Edit entry'), findsOne);
  });

  testWidgets('a page asked to add opens the event form', (tester) async {
    final starts = CalendarStarts()..ask(pageFile, const StartAdding());
    await pumpPage(
      tester,
      calendarPart(newCalendarText('Home')),
      today: _today,
      starts: starts,
    );
    expect(find.text('New event'), findsOne);
  });

  testWidgets('a health calendar asked to add lists its kinds', (tester) async {
    final healthStarts = CalendarStarts()..ask(pageFile, const StartAdding());
    await pumpPage(
      tester,
      calendarPart(newCalendarText('Me', health: true)),
      today: _today,
      starts: healthStarts,
    );
    expect(find.text('Medication'), findsOne);
  });

  testWidgets('an event that is gone gets a hint; a start for another file '
      'stays', (tester) async {
    final other = RelPath.parse('b.ics')!;
    final starts = CalendarStarts()
      ..ask((folder: pageFolder, path: other), const StartAdding())
      ..ask(
        pageFile,
        EditOccurrence('gone', null, start: DateTime(2026, 11, 3, 9)),
      );
    final hints = <String>[];
    await pumpPage(
      tester,
      calendarPart(_call.text),
      today: _today,
      starts: starts,
      hints: hints,
    );
    expect(hints, ['This event is no longer in the calendar.']);
    expect(find.text('New event'), findsNothing);
    expect(starts.take((folder: pageFolder, path: other)), isA<StartAdding>());
  });

  testWidgets('the page Add button starts an hour from 9:00 today', (
    tester,
  ) async {
    await pumpPage(
      tester,
      calendarPart(newCalendarText('Home')),
      today: _today,
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsOne);
    expect(find.textContaining('9:00'), findsWidgets);
  });
}
