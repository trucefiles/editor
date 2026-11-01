import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'days.dart';

/// What an [occurrence] is called; "(No title)" if it has none.
String occurrenceTitle(Occurrence occurrence) =>
    switch (occurrence.part.summary.trim()) {
      '' => '(No title)',
      final title => title,
    };

/// When [occurrence] is, in [words] and on a 24-hour clock if [use24Hour]:
/// "All day", or its times of day (with the day it ends on if that is
/// another day).
String timesOf(
  MaterialLocalizations words,
  Occurrence occurrence, {
  required bool use24Hour,
}) {
  if (occurrence.allDay) return 'All day';
  String time(DateTime at) => words.formatTimeOfDay(
    TimeOfDay.fromDateTime(at),
    alwaysUse24HourFormat: use24Hour,
  );
  final (start, end) = (occurrence.start, occurrence.end);
  if (start == end) return time(start);
  return DateUtils.isSameDay(start, end)
      ? '${time(start)} – ${time(end)}'
      : '${time(start)} – ${words.formatShortMonthDay(end)} ${time(end)}';
}

/// The days [occurrence] shows on, each at midnight: from its start's day
/// to the day of its end (an end at midnight or a day's end is not one).
List<DateTime> daysOf(Occurrence occurrence) {
  final first = DateUtils.dateOnly(occurrence.start);
  final last = DateUtils.dateOnly(
    occurrence.end.isAfter(occurrence.start)
        ? occurrence.end.subtract(const Duration(microseconds: 1))
        : occurrence.start,
  );
  return daysFrom(first, nextDay(last));
}

/// How many of [occurrences] show on each day, as a month grid marks it.
Map<DateTime, int> countsByDay(Iterable<Occurrence> occurrences) => {
  for (final MapEntry(key: day, value: shown) in groupBy(
    occurrences.expand(daysOf),
    (DateTime day) => day,
  ).entries)
    day: shown.length,
};
