import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_documents/truce_documents.dart';

import 'calendar_tab_controller.dart';

/// What the Calendar tab shows now: the [month] and picked [day], [today],
/// and the calendar the user added to last ([lastUsed]), offered first.
typedef TabPicks = ({
  DateTime month,
  DateTime day,
  DateTime today,
  Document? lastUsed,
});

/// One event of the picked day, with the calendar it is of.
typedef TabOccurrence = ({TabCalendar calendar, Occurrence occurrence});

/// The Calendar tab's month as it shows: how many events each day has,
/// the picked day's events, and the calendars to add to, the one used
/// last first.
typedef TabMonth = ({
  TabPicks picks,
  List<TabCalendar> calendars,
  Map<DateTime, int> counts,
  List<TabOccurrence> ofDay,
  List<TabCalendar> forAdding,
});

final calendarTabPicksProvider = NotifierProvider<CalendarTabPicks, TabPicks>(
  CalendarTabPicks.new,
);

/// The month and day the Calendar tab shows, as the user picks them; it
/// starts at today.
class CalendarTabPicks extends Notifier<TabPicks> {
  @override
  TabPicks build() {
    final today = DateUtils.dateOnly(DateTime.now());
    return (
      month: DateTime(today.year, today.month),
      day: today,
      today: today,
      lastUsed: null,
    );
  }

  /// Shows [month].
  void showMonth(DateTime month) => state = (
    month: month,
    day: state.day,
    today: state.today,
    lastUsed: state.lastUsed,
  );

  /// Picks [day], and shows its month.
  void pickDay(DateTime day) => state = (
    month: DateTime(day.year, day.month),
    day: day,
    today: state.today,
    lastUsed: state.lastUsed,
  );

  /// The user adds to [calendar]: offered first next time.
  void addTo(Document calendar) => state = (
    month: state.month,
    day: state.day,
    today: state.today,
    lastUsed: calendar,
  );
}

/// The tab's month for weeks that start on [firstWeekday] (the locale's,
/// 0 for Sunday).
final calendarTabMonthProvider = Provider.family<TabMonth, int>(
  (ref, firstWeekday) => tabMonth(
    ref.watch(calendarTabProvider).value ?? const [],
    ref.watch(calendarTabPicksProvider),
    firstWeekday: firstWeekday,
  ),
);

/// The month [picks] shows of [calendars], for weeks that start on
/// [firstWeekday]: the events of the calendars shown, by day.
TabMonth tabMonth(
  List<TabCalendar> calendars,
  TabPicks picks, {
  required int firstWeekday,
}) {
  final shown = {
    for (final calendar in calendars)
      if (calendar.shown) calendar: calendar.calendar,
  };
  final (:first, :end) = gridDays(picks.month, firstWeekday);
  final day = picks.day;
  return (
    picks: picks,
    calendars: calendars,
    counts: countsByDay(
      occurrencesOf(shown, first, end).map((each) => each.occurrence),
    ),
    ofDay: occurrencesOf(
      shown,
      day,
      DateTime(day.year, day.month, day.day + 1),
    ),
    forAdding: [
      ...calendars.where((each) => each.document == picks.lastUsed),
      ...calendars.where((each) => each.document != picks.lastUsed),
    ],
  );
}

/// What [calendar] is called: its own name, else its file's.
String tabCalendarName(TabCalendar calendar) =>
    switch (calendar.calendar.name.trim()) {
      '' => nameTitle(calendar.document.path),
      final name => name,
    };
