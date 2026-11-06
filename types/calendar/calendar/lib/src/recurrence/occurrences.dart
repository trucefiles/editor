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

  /// Whether it overlaps [from] to [to]; one with no length overlaps
  /// where it starts. The rule [occurrences] picks them by.
  bool overlaps(DateTime from, DateTime to) => _overlaps(start, end, from, to);
}

/// The occurrences of [calendar]'s events that overlap [from] to [to] (on
/// this device's clock), by start: repeats expanded, left-out ones
/// skipped, changed ones in place; deleted and cancelled events left out.
List<Occurrence> occurrences(Calendar calendar, DateTime from, DateTime to) {
  final span = _Span(from, to);
  return [for (final event in calendar.events) ..._occurrencesOf(event, span)]
    ..sort((a, b) => a.start.compareTo(b.start));
}

/// A span of time on this device's clock, [from] to [to], and the wall
/// clocks around it that a time written in any zone may show in it.
final class _Span {
  _Span(this.from, this.to)
    : wallFrom = _wallOf(from).subtract(_zoneGap),
      wallTo = _wallOf(to).add(_zoneGap);

  final DateTime from;
  final DateTime to;
  final DateTime wallFrom;
  final DateTime wallTo;

  /// Whether [start] to [end] (as written) overlaps it on this device's
  /// clock. The written clocks are checked first: turning a time into
  /// this device's clock is the costly part, so only times near the span
  /// are turned.
  bool overlaps(CalendarTime start, CalendarTime end) =>
      start.wall.isBefore(wallTo) &&
      !end.wall.isBefore(wallFrom) &&
      _overlaps(start.local, end.local, from, to);
}

/// The widest gap between two zones' clocks (UTC−12 to UTC+14): a time
/// written in one zone shows at most this far from its wall clock on
/// this device's.
const _zoneGap = Duration(hours: 26);

Iterable<Occurrence> _occurrencesOf(CalendarEvent event, _Span span) sync* {
  final series = event.series;
  if (series.changesOccurrence) {
    // Changed dates only (e.g. invites for single dates of a series held
    // elsewhere): each shows on its own; the first as the event itself.
    yield* [
      ?_shownAt(event, series, span),
      for (final part in event.changed)
        ?_shownAt(event, part, span, recurrence: part.recurrenceId),
    ];
    return;
  }
  final (start, end) = (series.start, series.end);
  if (start == null || end == null || series.cancelled || series.deleted) {
    return;
  }
  final rule = series.rule;
  if (rule == null && series.rdates.isEmpty) {
    yield* [?_shownAt(event, series, span)];
    return;
  }
  final length = lengthOn(start, end);
  final skipped = {
    for (final exdate in series.exdates) exdate.local,
    for (final part in event.changed) ?part.recurrenceId?.local,
  };
  // The rule as written: the one other apps read too.
  for (final wall in _instances(series, rule, span, length)) {
    final instance = start.at(wall);
    final local = instance.local;
    final localEnd = start.at(wall.add(length)).local;
    if (!skipped.contains(local) &&
        _overlaps(local, localEnd, span.from, span.to)) {
      yield Occurrence(
        event,
        series,
        start: local,
        end: localEnd,
        recurrence: instance,
      );
    }
  }
  // A changed date that names no occurrence is kept, never shown.
  yield* [
    for (final part in event.changed)
      if (part.recurrenceId case final recurrence?)
        ?_shownAt(event, part, span, recurrence: recurrence),
  ];
}

/// [part] of [event] shown where it is written, as the occurrence
/// [recurrence]; `null` where its times can't be read, it is cancelled,
/// or it is outside [span].
Occurrence? _shownAt(
  CalendarEvent event,
  EventPart part,
  _Span span, {
  CalendarTime? recurrence,
}) => switch ((part.start, part.end)) {
  (final start?, final end?)
      when !part.cancelled && span.overlaps(start, end) =>
    Occurrence(
      event,
      part,
      start: start.local,
      end: end.local,
      recurrence: recurrence,
    ),
  _ => null,
};

/// How many steps from a series' start the library may walk before it
/// stops: its highest limit. A series past it shows up to there.
const _steps = RecurrenceIterator.absoluteMaxIterations;

/// The wall clocks of [series]' occurrences (its [rule] and its extra
/// dates) that may overlap [span], by its wall clocks. A rule the library
/// can't read gives only the start.
///
/// The library walks wall clocks: each goes in and comes out as a UTC
/// time holding the wall clock's fields, so no zone's clock change moves
/// it. Its types stay in this function.
List<DateTime> _instances(
  EventPart series,
  String? rule,
  _Span span,
  Duration length,
) {
  final start = series.start!;
  final before = span.wallTo;
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
  final after = span.wallFrom.subtract(length);
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
    _Span(at.subtract(near), at.add(near)),
  ).any((each) => each.recurrence?.local == at);
}
