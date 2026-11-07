import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

/// What an [occurrence] is called; "(No title)" if it has none.
String occurrenceTitle(Occurrence occurrence) =>
    switch (occurrence.part.summary.trim()) {
      '' => '(No title)',
      final title => title,
    };

/// When [occurrence] is, in [words] and on a 24-hour clock if [use24Hour]:
/// "All day" (with its last day if that is another day), or its times of
/// day (with the day it ends on if that is another day).
String timesOf(
  MaterialLocalizations words,
  Occurrence occurrence, {
  required bool use24Hour,
}) {
  final (start, end) = (occurrence.start, occurrence.end);
  if (occurrence.allDay) {
    // Its end is the day after its last.
    final last = DateTime(end.year, end.month, end.day - 1);
    return last.isAfter(start)
        ? 'All day, until ${words.formatShortMonthDay(last)}'
        : 'All day';
  }
  String time(DateTime at) => words.formatTimeOfDay(
    TimeOfDay.fromDateTime(at),
    alwaysUse24HourFormat: use24Hour,
  );
  if (start == end) return time(start);
  return DateUtils.isSameDay(start, end)
      ? '${time(start)} – ${time(end)}'
      : '${time(start)} – ${words.formatShortMonthDay(end)} ${time(end)}';
}

/// When [occurrence] is on its own clock, where that is a time zone's
/// and shows other times than this device's: e.g. "In Europe/Berlin:
/// 10:00 – 13:00", or by two zones "10:00 Europe/London – 13:00
/// America/New York"; `null` for one all day or on this device's clock.
String? ownTimesOf(
  MaterialLocalizations words,
  Occurrence occurrence, {
  required bool use24Hour,
}) => switch ((occurrence.part.start, occurrence.part.end)) {
  (final start?, final end?) when !occurrence.allDay => _ownTimes(
    words,
    start.sameKindAt(occurrence.start),
    end.sameKindAt(occurrence.end),
    shown: occurrence,
    use24Hour: use24Hour,
  ),
  _ => null,
};

/// [start] to [end], on their own clocks, unless both are as [shown]
/// shows them.
String? _ownTimes(
  MaterialLocalizations words,
  CalendarTime start,
  CalendarTime end, {
  required Occurrence shown,
  required bool use24Hour,
}) {
  final (startZone, endZone) = (start.zone, end.zone);
  if ((startZone, endZone) == (null, null) ||
      (_sameClock(start.wall, shown.start) &&
          _sameClock(end.wall, shown.end))) {
    return null;
  }
  String time(DateTime wall) => words.formatTimeOfDay(
    TimeOfDay(hour: wall.hour, minute: wall.minute),
    alwaysUse24HourFormat: use24Hour,
  );
  final endTime = DateUtils.isSameDay(start.wall, end.wall)
      ? time(end.wall)
      : '${words.formatShortMonthDay(end.wall)} ${time(end.wall)}';
  String zone(String? name) => name == null ? 'local time' : zoneText(name);
  return startZone == endZone
      ? 'In ${zone(startZone)}: ${time(start.wall)} – $endTime'
      : '${time(start.wall)} ${zone(startZone)} – $endTime ${zone(endZone)}';
}

/// How a time zone (an IANA name) reads, e.g. "America/New York".
String zoneText(String zone) => zone.replaceAll('_', ' ');

/// Whether the wall clock [wall] shows as [local] does.
bool _sameClock(DateTime wall, DateTime local) =>
    (wall.year, wall.month, wall.day, wall.hour, wall.minute) ==
    (local.year, local.month, local.day, local.hour, local.minute);

/// Writes the day [start] is on, and its clock time unless the thing
/// lasts [allDay] (e.g. "Fri, Mar 12, 14:00").
typedef DayText = String Function(DateTime start, {required bool allDay});

/// [occurrence] in one line, e.g. on a card: its day by [day], then its
/// title.
String occurrenceLine(Occurrence occurrence, DayText day) =>
    '${day(occurrence.start, allDay: occurrence.allDay)}  '
    '${occurrenceTitle(occurrence)}';
