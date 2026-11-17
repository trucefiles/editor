import 'package:truce_calendar/truce_calendar.dart';

/// The tasks list of [calendars] as of [today], each calendar walked.
TaskList<K> taskListOf<K>(Map<K, Calendar> calendars, DateTime today) =>
    taskList({
      for (final MapEntry(:key, :value) in calendars.entries)
        key: calendarTaskEntries(value, today),
    }, today);
