import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

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

/// Writes the day [start] is on, and its clock time unless the thing
/// lasts [allDay] (e.g. "Fri, Mar 12, 14:00").
typedef DayText = String Function(DateTime start, {required bool allDay});

/// [occurrence] in one line, e.g. on a card: its day by [day], then its
/// title.
String occurrenceLine(Occurrence occurrence, DayText day) =>
    '${day(occurrence.start, allDay: occurrence.allDay)}  '
    '${occurrenceTitle(occurrence)}';
