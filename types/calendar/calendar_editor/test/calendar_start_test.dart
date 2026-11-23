import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'page_harness.dart';
import 'views_title.dart';

final _today = DateTime(2026, 11, 3);

/// A calendar with "Call" on [_today] from 9 for an hour.
final _call = applyEdit(
  Calendar.read(newCalendarText('Home'))!,
  AddItem(
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
    await tester.enterText(find.widgetWithText(TextField, 'Location'), 'Home');
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
      AddItem(
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
    await pickNew(tester, 'Event');
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
    expect(
      starts.take((folder: pageFolder, path: other))?.start,
      isA<StartAdding>(),
    );
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
    await pickNew(tester, 'Event');
    expect(find.text('New event'), findsOne);
    expect(find.textContaining('9:00'), findsWidgets);
  });

  testWidgets('a text that is no calendar shows no Add button', (tester) async {
    await pumpPage(tester, calendarPart('Not a calendar'), today: _today);
    expect(
      find.text(
        "This file can't be read as a calendar, so it's shown as plain "
        "text and can't be changed here.",
      ),
      findsOne,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('after a start from the tab, the Add button still adds', (
    tester,
  ) async {
    final starts = CalendarStarts()..ask(pageFile, const StartAdding());
    await pumpPage(
      tester,
      calendarPart(newCalendarText('Home')),
      today: _today,
      starts: starts,
    );
    await pickNew(tester, 'Event');
    Navigator.pop(tester.element(find.text('New event')));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await pickNew(tester, 'Event');
    expect(find.text('New event'), findsOne);
  });

  testWidgets('a later one of a series asked to edit shows its choices', (
    tester,
  ) async {
    final weekly = applyEdit(
      Calendar.read(newCalendarText('Home'))!,
      AddItem(
        'gym',
        EventDraft(
          summary: 'Gym',
          start: Floating(DateTime.utc(2026, 10, 20, 18)),
          end: Floating(DateTime.utc(2026, 10, 20, 19)),
          repeat: const SimpleRepeat(Frequency.weekly),
        ),
        at: editedAt,
      ),
    );
    final later =
        occurrences(weekly, DateTime(2026, 11, 3), DateTime(2026, 11, 4)).single
            as EventOccurrence;
    final starts = CalendarStarts()..ask(pageFile, EditOccurrence.of(later));
    final hints = <String>[];
    await pumpPage(
      tester,
      calendarPart(weekly.text),
      today: _today,
      starts: starts,
      hints: hints,
    );
    expect(hints, isEmpty);
    expect(find.text('Edit this one'), findsOne);
  });

  testWidgets('a page asked to show a day in a view shows it there, and '
      'keeps its own view', (tester) async {
    final kept = KeptView();
    final starts = CalendarStarts()
      ..ask(
        pageFile,
        null,
        showAt: ShowAt(CalendarViewKind.day, day: DateTime(2027, 1, 14)),
      );
    await pumpPage(
      tester,
      calendarPart(_call.text, kept: kept),
      today: _today,
      starts: starts,
    );
    expect(viewsTitle('Thu, Jan 14'), findsOne);
    expect(kept.kind, CalendarViewKind.month);
    expect(find.text('New event'), findsNothing, reason: 'nothing started');
  });

  testWidgets('an event asked to edit at its day: the page behind its form '
      'shows that day', (tester) async {
    final call =
        occurrences(_call, DateTime(2026, 11, 3), DateTime(2026, 11, 4)).single
            as EventOccurrence;
    final starts = CalendarStarts()
      ..ask(
        pageFile,
        EditOccurrence.of(call),
        showAt: ShowAt.occurrence(CalendarViewKind.day, call),
      );
    await pumpPage(
      tester,
      calendarPart(_call.text),
      today: DateTime(2026, 12, 20),
      starts: starts,
    );
    expect(find.text('Edit event'), findsOne);
    Navigator.pop(tester.element(find.text('Edit event')));
    await tester.pumpAndSettle();
    expect(viewsTitle('Tue, Nov 3'), findsOne);
    expect(find.text('Call'), findsOne);
  });

  testWidgets('a page shown in the tasks view adds a task, though it keeps '
      'the month', (tester) async {
    final starts = CalendarStarts()
      ..ask(pageFile, null, showAt: const ShowAt(CalendarViewKind.tasks));
    await pumpPage(
      tester,
      calendarPart(newCalendarText('Home')),
      today: _today,
      starts: starts,
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOne);
  });

  group('ShowAt', () {
    const week = CalendarViewKind.week;

    test('a timed event shows on its day from its time', () {
      final call =
          occurrences(
                _call,
                DateTime(2026, 11, 3),
                DateTime(2026, 11, 4),
              ).single
              as EventOccurrence;
      final at = ShowAt.occurrence(week, call);
      expect(at.kind, week);
      expect(at.day, DateTime(2026, 11, 3));
      expect(at.time, const TimeOfDay(hour: 9, minute: 0));
    });

    test('an all-day event shows on its day from the morning', () {
      final holiday = applyEdit(
        Calendar.read(newCalendarText('Home'))!,
        AddItem(
          'off',
          EventDraft(
            summary: 'Off',
            start: AllDay(DateTime.utc(2026, 11, 5)),
            end: AllDay(DateTime.utc(2026, 11, 6)),
          ),
          at: editedAt,
        ),
      );
      final off =
          occurrences(
                holiday,
                DateTime(2026, 11, 5),
                DateTime(2026, 11, 6),
              ).single
              as EventOccurrence;
      final at = ShowAt.occurrence(week, off);
      expect(at.day, DateTime(2026, 11, 5));
      expect(at.time, isNull);
    });

    test('a timed task shows from where its tile starts, before it is '
        'due', () {
      final home = applyEdit(
        Calendar.read(newCalendarText('Home'))!,
        AddItem(
          'water',
          TaskDraft(
            summary: 'Water',
            due: Floating(DateTime.utc(2026, 11, 3, 9)),
          ),
          at: editedAt,
        ),
      );
      final task =
          occurrences(home, DateTime(2026, 11, 3), DateTime(2026, 11, 4)).single
              as TaskOccurrence;
      final at = ShowAt.task(week, TaskEntry.of(task));
      expect(at.day, DateTime(2026, 11, 3));
      expect(at.time, const TimeOfDay(hour: 8, minute: 30));
    });

    test('a task due never shows on today', () {
      final home = applyEdit(
        Calendar.read(newCalendarText('Home'))!,
        AddItem('water', const TaskDraft(summary: 'Water'), at: editedAt),
      );
      final at = ShowAt.task(week, TaskEntry.undated(home.tasks.single));
      expect(at.day, isNull);
      expect(at.time, isNull);
    });

    test("an item from its start alone (an alert's) shows in the page's "
        'own view, a timed task where its tile starts', () {
      final task = ShowAt.item(
        null,
        ItemKind.task,
        DateTime(2026, 11, 3, 9),
        allDay: false,
      );
      expect(task.kind, isNull);
      expect(task.day, DateTime(2026, 11, 3));
      expect(task.time, const TimeOfDay(hour: 8, minute: 30));

      final event = ShowAt.item(
        null,
        ItemKind.event,
        DateTime(2026, 11, 3, 9),
        allDay: false,
      );
      expect(event.time, const TimeOfDay(hour: 9, minute: 0));
    });
  });
}
