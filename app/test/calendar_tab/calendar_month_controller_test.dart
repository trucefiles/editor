import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_editor/calendar_tab/calendar_month_controller.dart';
import 'package:truce_editor/calendar_tab/calendar_tab_controller.dart';

import '../support.dart';

void main() {
  final folder = folderAt(Directory('/documents'));

  /// A calendar named [name] with one [event] on [day] from 9 to 10.
  TabCalendar calendar(
    String name,
    String event,
    DateTime day, {
    bool shown = true,
  }) => (
    document: listedDocument(folder, name: '${name.toLowerCase()}.ics'),
    calendar: applyEdit(
      Calendar.read(newCalendarText(name))!,
      AddEvent(
        event,
        EventDraft(
          summary: event,
          start: Floating(DateTime.utc(day.year, day.month, day.day, 9)),
          end: Floating(DateTime.utc(day.year, day.month, day.day, 10)),
        ),
        at: DateTime.utc(2026, 11),
      ),
    ),
    shown: shown,
  );

  TabPicks picks(DateTime day, {TabCalendar? lastUsed}) => (
    month: DateTime(day.year, day.month),
    day: day,
    today: DateTime(2026, 11, 1),
    lastUsed: lastUsed?.document.key,
  );

  final home = calendar('Home', 'Dentist', DateTime(2026, 11, 5));
  final work = calendar('Work', 'Review', DateTime(2026, 11, 5));
  final hidden = calendar('Club', 'Match', DateTime(2026, 11, 5), shown: false);

  test("the month joins the shown calendars' events by day", () {
    final month = tabMonth(
      [home, work, hidden],
      picks(DateTime(2026, 11, 5)),
      firstWeekday: 0,
    );

    expect(month.counts, {DateTime(2026, 11, 5): 2});
    expect([
      for (final (:calendar, :occurrence) in month.ofDay)
        (tabCalendarName(calendar), occurrence.part.summary),
    ], unorderedEquals([('Home', 'Dentist'), ('Work', 'Review')]));
  });

  test('the calendar added to last is offered first', () {
    final month = tabMonth(
      [home, work],
      picks(DateTime(2026, 11, 5), lastUsed: work),
      firstWeekday: 0,
    );

    expect(
      [for (final each in month.forAdding) tabCalendarName(each)],
      ['Work', 'Home'],
    );
  });

  test('picking a day shows its month; it starts at today', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final today = DateTime.now();
    expect(
      container.read(calendarTabPicksProvider).day,
      (DateTime(today.year, today.month, today.day)),
    );

    container
        .read(calendarTabPicksProvider.notifier)
        .pickDay(DateTime(2027, 3, 12));

    final picked = container.read(calendarTabPicksProvider);
    expect(
      (picked.month, picked.day),
      (DateTime(2027, 3), DateTime(2027, 3, 12)),
    );
  });

  test('the calendar added to stays first once it changed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(calendarTabPicksProvider.notifier).addTo(work.document);
    final changed = (
      document: listedDocument(folder, name: 'work.ics', version: 1),
      calendar: work.calendar,
      shown: true,
    );

    final month = tabMonth(
      [home, changed],
      container.read(calendarTabPicksProvider),
      firstWeekday: 0,
    );

    expect(tabCalendarName(month.forAdding.first), 'Work');
  });

  testWidgets('today moves on at midnight', (tester) async {
    var now = DateTime(2026, 11, 1, 23, 59);
    final container = ProviderContainer(
      overrides: [calendarClockProvider.overrideWithValue(() => now)],
    );
    expect(container.read(calendarTabPicksProvider).today, DateTime(2026, 11));

    now = DateTime(2026, 11, 2);
    await tester.pump(const Duration(minutes: 1));

    expect(
      container.read(calendarTabPicksProvider).today,
      DateTime(2026, 11, 2),
    ); // Ends the next midnight's wake before the test checks for timers.
    container.dispose();
  });
}
