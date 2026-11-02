import 'package:flutter/gestures.dart';
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

/// A calendar with one event, "Call", on [start] for an hour.
String _call(CalendarTime start) => applyEdit(
  Calendar.read(newCalendarText('Home'))!,
  AddEvent(
    'call',
    EventDraft(
      summary: 'Call',
      start: start,
      end: start.at(start.wall.add(const Duration(hours: 1))),
    ),
    at: editedAt,
  ),
).text;

/// Drags what [finder] finds by [offset] with [kind] of pointer: held a
/// moment first (a long press on touch), then moved in small steps.
Future<void> _drag(
  WidgetTester tester,
  Offset from,
  Offset offset, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final gesture = await tester.startGesture(from, kind: kind);
  await tester.pump(const Duration(milliseconds: 600));
  for (var step = 0; step < 10; step++) {
    await gesture.moveBy(offset / 10);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// How tall an hour is in the week and day views.
const _hour = 42.0;

void main() {
  testWidgets('an event added on the day shown, stamped when added; '
      'floating where the device zone is unknown', (tester) async {
    final part = calendarPart(newCalendarText('Home'));
    await pumpPage(tester, part, today: DateTime(2026, 11, 3));

    await tester.tap(find.byTooltip('Add event'));
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

  testWidgets('a new event is in the device zone, its block in the file', (
    tester,
  ) async {
    final part = calendarPart(newCalendarText('Home'));
    await pumpPage(
      tester,
      part,
      today: DateTime(2026, 11, 3),
      deviceZone: 'Europe/Berlin',
    );

    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Times are in'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Call');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final event = calendarOf(part).events.single.series;
    expect(event.start, Zoned('Europe/Berlin', DateTime.utc(2026, 11, 3, 9)));
    expect(calendarOf(part).zones, {'Europe/Berlin'});
  });

  testWidgets('an event in UTC says so', (tester) async {
    final calendar = applyEdit(
      Calendar.read(newCalendarText('Home'))!,
      AddEvent(
        'call',
        EventDraft(
          summary: 'Call',
          start: UtcTime(DateTime.utc(2026, 11, 3, 9)),
          end: UtcTime(DateTime.utc(2026, 11, 3, 10)),
        ),
        at: editedAt,
      ),
    );
    await pumpPage(
      tester,
      calendarPart(calendar.text),
      today: DateTime(2026, 11, 3),
      deviceZone: 'Europe/Berlin',
    );
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Times are in UTC.'), findsOne);
  });

  testWidgets('an event of another zone shows and keeps its zone', (
    tester,
  ) async {
    final calendar = applyEdit(
      Calendar.read(newCalendarText('Home'))!,
      AddEvent(
        'call',
        EventDraft(
          summary: 'Call',
          start: Zoned('America/New_York', DateTime.utc(2026, 11, 3, 9)),
          end: Zoned('America/New_York', DateTime.utc(2026, 11, 3, 10)),
        ),
        at: editedAt,
      ),
    );
    final part = calendarPart(calendar.text);
    await pumpPage(
      tester,
      part,
      today: DateTime(2026, 11, 3),
      deviceZone: 'Europe/Berlin',
    );

    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Times are in America/New_York.'), findsOne);
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Late call',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final event = calendarOf(part).events.single.series;
    expect(event.summary, 'Late call');
    expect(
      event.start,
      Zoned('America/New_York', DateTime.utc(2026, 11, 3, 9)),
    );
  });

  testWidgets('one of a series deleted; the others stay', (tester) async {
    final part = calendarPart(_birthday);
    await pumpPage(tester, part, today: _annsDay);

    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    expect(find.text('Friday, March 12, 2027 · All day'), findsOne);
    expect(find.text('Edit all of them'), findsOne);
    await tester.tap(find.text('Delete this one'));
    await tester.pumpAndSettle();

    expect(_on(part, _annsDay), isEmpty);
    expect(_on(part, DateTime(2028, 3, 12)), ['Ann']);
    expect(find.text('Ann'), findsNothing);
  });

  testWidgets('one of a series edited starts at its own day', (tester) async {
    final part = calendarPart(_birthday);
    await pumpPage(tester, part, today: _annsDay);

    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit this one'));
    await tester.pumpAndSettle();
    expect(find.text('Repeats'), findsNothing, reason: 'one of a series');
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

  testWidgets('a read-only calendar shows an event and offers no edits', (
    tester,
  ) async {
    final part = calendarPart(_birthday, readOnly: true);
    await pumpPage(tester, part, today: _annsDay);

    expect(find.byTooltip('Add event'), findsNothing);
    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    expect(find.text('Friday, March 12, 2027 · All day'), findsOne);
    expect(find.text('Delete this one'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('20')) + const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsNothing);
    await _drag(
      tester,
      tester.getCenter(find.text('Ann')),
      const Offset(120, 0),
    );
    expect(part.owner.state.text, _birthday);
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

  testWidgets("times show on the system's clock", (tester) async {
    final calendar = applyEdit(
      Calendar.read(newCalendarText('Home'))!,
      AddEvent(
        'swim',
        EventDraft(
          summary: 'Swimming',
          start: Floating(DateTime.utc(2026, 11, 2, 17)),
          end: Floating(DateTime.utc(2026, 11, 2, 18)),
        ),
        at: editedAt,
      ),
    );
    tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
    addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
    await pumpPage(
      tester,
      calendarPart(calendar.text),
      today: DateTime(2026, 11, 2),
      kept: KeptView(CalendarViewKind.schedule),
    );

    expect(find.text('17:00 – 18:00'), findsOne);
  });

  testWidgets('a form saved after the calendar turned read only changes '
      'nothing', (tester) async {
    final part = calendarPart(_birthday);
    final hints = <String>[];
    await pumpPage(tester, part, today: _annsDay, hints: hints);
    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Late');

    part.showReadOnly(readOnly: true);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(part.owner.state.text, _birthday);
    expect(hints, ["The calendar can't be edited right now."]);
  });

  testWidgets('the page opens in the view picked last, and keeps a new '
      'pick', (tester) async {
    final kept = KeptView(CalendarViewKind.week);
    await pumpPage(
      tester,
      calendarPart(_call(Floating(DateTime.utc(2026, 11, 3, 9)))),
      today: DateTime(2026, 11, 3),
      kept: kept,
    );
    expect(find.byIcon(Icons.calendar_view_week), findsOne);
    expect(find.text('Call'), findsOne);

    await tester.tap(find.byTooltip('Pick a view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('Tue, Nov 3'), findsOne, reason: 'on today');
    expect(find.text('Call'), findsOne);

    await tester.tap(find.byTooltip('Pick a view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule').last);
    await tester.pumpAndSettle();

    expect(kept.kind, CalendarViewKind.schedule);
    expect(find.text('Call'), findsOne);
    expect(find.text('9:00 AM – 10:00 AM'), findsOne);
  });

  testWidgets('a tap on a free time asks for an event at that time', (
    tester,
  ) async {
    final part = calendarPart(_call(Floating(DateTime.utc(2026, 11, 3, 9))));
    await pumpPage(
      tester,
      part,
      today: DateTime(2026, 11, 3),
      kept: KeptView(CalendarViewKind.day),
    );

    final call = tester.getRect(find.text('Call'));
    await tester.tapAt(call.topCenter + const Offset(0, 3 * _hour + 2));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Lunch');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final lunch = calendarOf(part).events
        .firstWhere((event) => event.series.summary == 'Lunch');
    expect(
      (lunch.series.start, lunch.series.end),
      (
        Floating(DateTime.utc(2026, 11, 3, 12)),
        Floating(DateTime.utc(2026, 11, 3, 13)),
      ),
    );
  });

  testWidgets('a tap on a day of the month asks for an event that day', (
    tester,
  ) async {
    final part = calendarPart(newCalendarText('Home'));
    await pumpPage(tester, part, today: DateTime(2026, 11, 3));

    await tester.tapAt(tester.getCenter(find.text('20')) + const Offset(0, 40));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Party');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_on(part, DateTime(2026, 11, 20)), ['Party']);
  });

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('a drag moves an event (${kind.name})', (tester) async {
      final part = calendarPart(
        _call(Zoned('America/New_York', DateTime.utc(2026, 11, 3, 9))),
      );
      await pumpPage(
        tester,
        part,
        today: DateTime(2026, 11, 3),
        kept: KeptView(CalendarViewKind.week),
      );

      await _drag(
        tester,
        tester.getCenter(find.text('Call')),
        const Offset(0, 2 * _hour),
        kind: kind,
      );

      final call = calendarOf(part).events.single.series;
      expect(
        (call.start, call.end),
        (
          Zoned('America/New_York', DateTime.utc(2026, 11, 3, 11)),
          Zoned('America/New_York', DateTime.utc(2026, 11, 3, 12)),
        ),
        reason: 'it stays in its zone',
      );
    });
  }

  testWidgets('a drag of one of a series moves only that date', (tester) async {
    final part = calendarPart(_birthday);
    await pumpPage(tester, part, today: _annsDay);

    await _drag(
      tester,
      tester.getCenter(find.text('Ann')),
      tester.getCenter(find.text('14')) - tester.getCenter(find.text('12')),
    );

    expect(_on(part, _annsDay), isEmpty);
    expect(_on(part, DateTime(2027, 3, 14)), ['Ann']);
    expect(_on(part, DateTime(2028, 3, 12)), ['Ann']);
    expect(
      calendarOf(part).events.single.changed.single.start,
      AllDay(DateTime(2027, 3, 14)),
    );
  });

  testWidgets('a drag of its end makes an event longer', (tester) async {
    final part = calendarPart(_call(Floating(DateTime.utc(2026, 11, 3, 9))));
    await pumpPage(
      tester,
      part,
      today: DateTime(2026, 11, 3),
      kept: KeptView(CalendarViewKind.day),
    );

    final tile = tester.getRect(
      find
          .ancestor(of: find.text('Call'), matching: find.byType(Container))
          .first,
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tile.center);
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    final edge = tile.bottomCenter - const Offset(0, 2);
    await mouse.moveTo(edge);
    await tester.pumpAndSettle();
    await mouse.down(edge);
    await tester.pump(const Duration(milliseconds: 100));
    for (var step = 0; step < 10; step++) {
      await mouse.moveBy(const Offset(0, _hour / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.pumpAndSettle();

    final event = calendarOf(part).events.single.series;
    expect(
      (event.start, event.end),
      (
        Floating(DateTime.utc(2026, 11, 3, 9)),
        Floating(DateTime.utc(2026, 11, 3, 11)),
      ),
    );
  });

  testWidgets('a drag over free times asks for an event over them', (
    tester,
  ) async {
    final part = calendarPart(_call(Floating(DateTime.utc(2026, 11, 3, 9))));
    await pumpPage(
      tester,
      part,
      today: DateTime(2026, 11, 3),
      kept: KeptView(CalendarViewKind.day),
    );

    final call = tester.getRect(find.text('Call'));
    await _drag(
      tester,
      call.topCenter + const Offset(0, 3 * _hour + 2),
      const Offset(0, 2 * _hour),
      kind: PointerDeviceKind.mouse,
    );
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Lunch');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final lunch = calendarOf(part).events
        .firstWhere((event) => event.series.summary == 'Lunch')
        .series;
    expect(
      (lunch.start, lunch.end),
      (
        Floating(DateTime.utc(2026, 11, 3, 12)),
        Floating(DateTime.utc(2026, 11, 3, 14)),
      ),
    );
  });

  testWidgets('a drag over days asks for an all-day event over them', (
    tester,
  ) async {
    final part = calendarPart(newCalendarText('Home'));
    await pumpPage(tester, part, today: DateTime(2026, 11, 3));

    final from = tester.getCenter(find.text('10')) + const Offset(0, 40);
    final to = tester.getCenter(find.text('12')) + const Offset(0, 40);
    await _drag(tester, from, to - from, kind: PointerDeviceKind.mouse);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Trip');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final trip = calendarOf(part).events.single.series;
    expect(
      (trip.start, trip.end),
      (AllDay(DateTime(2026, 11, 10)), AllDay(DateTime(2026, 11, 13))),
    );
  });

  testWidgets('an event dropped where it was changes nothing', (tester) async {
    final part = calendarPart(_birthday);
    await pumpPage(
      tester,
      part,
      today: _annsDay,
      kept: KeptView(CalendarViewKind.week),
    );

    final ann = tester.getCenter(find.text('Ann'));
    final gesture = await tester.startGesture(ann);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(part.owner.state.text, _birthday);
  });
}
