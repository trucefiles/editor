import 'package:firstfloor_calendar/firstfloor_calendar.dart'
    show
        CalDateTime,
        ParseException,
        RecurrenceDateTime,
        RecurrenceIterator,
        RecurrenceRule,
        parseRecurrenceRuleValue;

import '../model/calendar.dart';
import '../model/calendar_event.dart';
import '../model/calendar_time.dart';
import '../model/wall_on.dart';

/// One occurrence of an event, as it shows: [part] says what it is (the
/// series, a single event, or a changed occurrence), from [start] to
/// [end] on this device's clock.
final class Occurrence {
  const Occurrence(
    this.event,
    this.part, {
    required this.start,
    required this.end,
    this.recurrence,
  });

  final CalendarEvent event;
  final EventPart part;
  final DateTime start;
  final DateTime end;

  /// Which occurrence of its series it is, as the series writes its
  /// start; `null` for an event that doesn't repeat.
  final CalendarTime? recurrence;

  bool get allDay => part.allDay;
}

/// The occurrences of [calendar]'s events that overlap [from] to [to] (on
/// this device's clock), by start: repeats expanded, left-out ones
/// skipped, changed ones in place; deleted and cancelled events left out.
List<Occurrence> occurrences(Calendar calendar, DateTime from, DateTime to) =>
    [for (final event in calendar.events) ..._occurrencesOf(event, from, to)]
      ..sort((a, b) => a.start.compareTo(b.start));

/// The occurrences of each of [calendars] that overlap [from] to [to], by
/// start, each with the key of its calendar.
List<({K calendar, Occurrence occurrence})> occurrencesOf<K>(
  Map<K, Calendar> calendars,
  DateTime from,
  DateTime to,
) => [
  for (final MapEntry(key: calendar, value: each) in calendars.entries)
    for (final occurrence in occurrences(each, from, to))
      (calendar: calendar, occurrence: occurrence),
]..sort((a, b) => a.occurrence.start.compareTo(b.occurrence.start));

Iterable<Occurrence> _occurrencesOf(
  CalendarEvent event,
  DateTime from,
  DateTime to,
) sync* {
  final series = event.series;
  final (start, end) = (series.start, series.end);
  if (start == null || end == null || series.cancelled || series.deleted) {
    return;
  }
  final rule = series.rule;
  if ((rule == null && series.rdates.isEmpty) || series.recurrenceId != null) {
    if (_overlaps(start.local, end.local, from, to)) {
      yield Occurrence(event, series, start: start.local, end: end.local);
    }
    return;
  }
  final length = lengthOn(start, end);
  final skipped = {
    for (final exdate in series.exdates) exdate.local,
    for (final part in event.changed) ?part.recurrenceId?.local,
  };
  // The rule as written: the one other apps read too.
  for (final wall in _instances(series, rule, from, to, length)) {
    final instance = start.at(wall);
    final local = instance.local;
    final localEnd = start.at(wall.add(length)).local;
    if (!skipped.contains(local) && _overlaps(local, localEnd, from, to)) {
      yield Occurrence(
        event,
        series,
        start: local,
        end: localEnd,
        recurrence: instance,
      );
    }
  }
  for (final part in event.changed) {
    final (partStart, partEnd) = (part.start, part.end);
    if (partStart == null || partEnd == null || part.cancelled) continue;
    if (_overlaps(partStart.local, partEnd.local, from, to)) {
      yield Occurrence(
        event,
        part,
        start: partStart.local,
        end: partEnd.local,
        recurrence: part.recurrenceId,
      );
    }
  }
}

/// How many steps from a series' start the library may walk before it
/// stops: its highest limit. A series past it shows up to there.
const _steps = RecurrenceIterator.absoluteMaxIterations;

/// The wall clocks of [series]' occurrences (its [rule] and its extra
/// dates) that may overlap [from] to [to]: a day more on each side, for
/// time zones. A rule the library can't read gives only the start.
///
/// The library walks wall clocks: each goes in and comes out as a UTC
/// time holding the wall clock's fields, so no zone's clock change moves
/// it. Its types stay in this function.
List<DateTime> _instances(
  EventPart series,
  String? rule,
  DateTime from,
  DateTime to,
  Duration length,
) {
  final start = series.start!;
  const margin = Duration(days: 1);
  final before = _wallOf(to).add(margin);
  if (start.wall.isAfter(before)) return const [];
  final RecurrenceRule? recurrence;
  try {
    recurrence = switch (rule) {
      final rule? => _onWallClocks(parseRecurrenceRuleValue(rule), start),
      null => null,
    };
  } on ParseException {
    return [start.wall];
  }
  final after = _wallOf(from).subtract(length + margin);
  final walls =
      RecurrenceIterator(
            dtstart: _calendarTime(start.wall),
            rrule: recurrence,
            rdates: [
              for (final extra in series.rdates)
                RecurrenceDateTime.dateTime(
                  _calendarTime(wallOn(start, extra)),
                ),
            ],
            maxIterations: _steps,
          )
          .occurrences(
            start: after.isAfter(start.wall) ? _calendarTime(after) : null,
            end: _calendarTime(before),
          )
          .map((wall) => wall.native);
  final found = <DateTime>[];
  try {
    found.addAll(walls);
  } on StateError {
    // The library tells it hit its step limit only by throwing, while it
    // walks: what came so far shows.
  }
  return found;
}

/// [rule] with its `UNTIL` as a wall clock on [start]'s clock and of its
/// kind, as the library compares it (RFC 5545 asks a UTC time for a
/// zoned start, which the library would read as a wall clock).
RecurrenceRule _onWallClocks(RecurrenceRule rule, CalendarTime start) {
  final until = rule.until;
  if (until == null) return rule;
  return RecurrenceRule(
    freq: rule.freq,
    until: _calendarTime(wallOn(start, _timeOf(until))),
    count: rule.count,
    interval: rule.interval,
    bySecond: rule.bySecond,
    byMinute: rule.byMinute,
    byHour: rule.byHour,
    byDay: rule.byDay,
    byMonthDay: rule.byMonthDay,
    byYearDay: rule.byYearDay,
    byWeekNo: rule.byWeekNo,
    byMonth: rule.byMonth,
    bySetPos: rule.bySetPos,
    wkst: rule.wkst,
  );
}

/// The library's [time] as one of ours.
CalendarTime _timeOf(CalDateTime time) => switch (time.time) {
  null => AllDay(DateTime.utc(time.year, time.month, time.day)),
  final clock => (clock.isUtc ? UtcTime.new : Floating.new)(
    DateTime.utc(
      time.year,
      time.month,
      time.day,
      clock.hour,
      clock.minute,
      clock.second,
    ),
  ),
};

/// The wall clock [wall] as the library walks it.
CalDateTime _calendarTime(DateTime wall) => CalDateTime.utc(
  wall.year,
  wall.month,
  wall.day,
  wall.hour,
  wall.minute,
  wall.second,
);

DateTime _wallOf(DateTime local) => DateTime.utc(
  local.year,
  local.month,
  local.day,
  local.hour,
  local.minute,
  local.second,
);

/// Whether [start] to [end] overlaps [from] to [to]; an event with no
/// length overlaps where it starts.
bool _overlaps(DateTime start, DateTime end, DateTime from, DateTime to) =>
    start.isBefore(to) &&
    (end.isAfter(from) || (end == start && !start.isBefore(from)));

/// Whether [event]'s series still has its occurrence at [occurrence] (as
/// the series writes its start): the series repeats on it, and it is
/// neither left out nor cancelled.
bool hasOccurrenceAt(CalendarEvent event, CalendarTime occurrence) {
  if (event.changedAt(occurrence) case final changed?) {
    return !changed.cancelled;
  }
  final at = occurrence.local;
  const near = Duration(minutes: 1);
  return _occurrencesOf(
    event,
    at.subtract(near),
    at.add(near),
  ).any((each) => each.recurrence?.local == at);
}
