import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'page_harness.dart';

const _birthday = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Truce Editor//Calendar//EN
X-WR-CALNAME:Birthdays
BEGIN:VEVENT
UID:ann@truce
DTSTAMP:20261001T080000Z
DTSTART;VALUE=DATE:20200312
DTEND;VALUE=DATE:20200313
RRULE:FREQ=YEARLY
SUMMARY:Ann
END:VEVENT
END:VCALENDAR
''';

final _annsDay = DateTime(2027, 3, 12);

/// What [part]'s calendar shows on [day].
List<String> _on(CalendarEditorPart part, DateTime day) => [
  for (final occurrence in occurrences(
    calendarOf(part),
    day,
    DateTime(day.year, day.month, day.day + 1),
  ))
    occurrence.part.summary,
];

void main() {
  testWidgets('an event added on the picked day, stamped when added', (
    tester,
  ) async {
    final part = calendarPart(newCalendarText('Home'));
    await pumpPage(tester, part, today: DateTime(2026, 11, 3));

    await tester.tap(find.text('Add event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Dentist');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_on(part, DateTime(2026, 11, 3)), ['Dentist']);
    expect(find.text('Dentist'), findsOne);
    final event = calendarOf(part).events.single.series;
    expect(event.start, Floating(DateTime.utc(2026, 11, 3, 9)));
    expect(part.owner.state.text, contains('DTSTAMP:20261101T120000Z'));
  });

  testWidgets('one of a series deleted; the others stay', (tester) async {
    final part = calendarPart(_birthday);
    await pumpPage(tester, part, today: _annsDay);

    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    expect(find.text('Edit all of them'), findsOne);
    await tester.tap(find.text('Delete this one'));
    await tester.pumpAndSettle();

    expect(_on(part, _annsDay), isEmpty);
    expect(_on(part, DateTime(2028, 3, 12)), ['Ann']);
    expect(find.text('Nothing on this day.'), findsOne);
  });

  testWidgets('one of a series edited starts at its own day', (tester) async {
    final part = calendarPart(_birthday);
    await pumpPage(tester, part, today: _annsDay);

    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit this one'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Ann (party)',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_on(part, _annsDay), ['Ann (party)']);
    expect(_on(part, DateTime(2028, 3, 12)), ['Ann']);
  });

  testWidgets('a whole series edited', (tester) async {
    final part = calendarPart(_birthday);
    await pumpPage(tester, part, today: _annsDay);

    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit all of them'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Place'), 'Home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(calendarOf(part).events.single.series.location, 'Home');
    expect(_on(part, DateTime(2028, 3, 12)), ['Ann']);
  });

  testWidgets('a read-only calendar offers no edits', (tester) async {
    final part = calendarPart(_birthday, readOnly: true);
    await pumpPage(tester, part, today: _annsDay);

    expect(find.text('Add event'), findsNothing);
    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this one'), findsNothing);
  });

  testWidgets('a text that is no calendar shows as it is', (tester) async {
    final part = calendarPart('not a calendar');
    await pumpPage(tester, part, today: _annsDay);

    expect(find.text('not a calendar'), findsOne);
  });

  testWidgets('undo from the page is stamped when it is asked', (tester) async {
    var now = editedAt;
    final part = calendarPart(_birthday, now: () => now);
    await pumpPage(tester, part, today: _annsDay);
    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all of them'));
    await tester.pumpAndSettle();

    now = DateTime.utc(2026, 11, 2, 8);
    part.editor.send(const Undo());
    await tester.pumpAndSettle();

    expect(_on(part, _annsDay), ['Ann']);
    expect(part.owner.state.text, contains('LAST-MODIFIED:20261102T080000Z'));
  });
}
