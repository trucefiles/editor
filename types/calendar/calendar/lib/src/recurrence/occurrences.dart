import 'package:firstfloor_calendar/firstfloor_calendar.dart'
    show
        CalDateTime,
        ParseException,
        RecurrenceDateTime,
        RecurrenceIterator,
        RecurrenceRule,
        parseRecurrenceRuleValue;

import '../model/calendar.dart';
import '../model/calendar_item.dart';
import '../model/calendar_time.dart';
import '../model/item_part.dart';
import '../model/occurrence.dart';
import '../model/wall_on.dart';

export '../model/occurrence.dart'
    show EventOccurrence, Occurrence, TaskOccurrence;

/// The occurrences of [calendar]'s events and tasks that overlap [from]
/// to [to] (on this device's clock), by start: repeats expanded,
/// left-out ones skipped, changed ones in place; deleted and cancelled
/// ones left out, and tasks without a due time.
List<Occurrence> occurrences(Calendar calendar, DateTime from, DateTime to) {
  final span = _Span(from, to);
  return [for (final item in calendar.items) ..._occurrencesOf(item, span)]
    ..sort((a, b) => a.start.compareTo(b.start));
}

/// The occurrences of [item] alone, as [occurrences] picks them, in the
/// order its dates come.
Iterable<Occurrence> occurrencesOf(
  CalendarItem item,
  DateTime from,
  DateTime to,
) => _occurrencesOf(item, _Span(from, to));

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
      spanOverlaps(start.local, end.local, from, to);
}

/// The widest gap between two zones' clocks (UTC−12 to UTC+14): a time
/// written in one zone shows at most this far from its wall clock on
/// this device's.
const _zoneGap = Duration(hours: 26);

Iterable<Occurrence> _occurrencesOf<P extends ItemPart>(
  CalendarItem<P> item,
  _Span span,
) sync* {
  final series = item.series;
  if (series.changesOccurrence) {
    // Changed dates only (e.g. invites for single dates of a series held
    // elsewhere): each shows on its own; the first as the item itself.
    yield* [
      ?_shownAt(item, series, span),
      for (final part in item.changed)
        ?_shownAt(item, part, span, recurrence: part.recurrenceId),
    ];
    return;
  }
  final (anchor, from, to) = (series.anchor, series.from, series.to);
  if (anchor == null ||
      from == null ||
      to == null ||
      series.cancelled ||
      series.deleted) {
    return;
  }
  final rule = series.rule;
  if (rule == null && series.rdates.isEmpty) {
    yield* [?_shownAt(item, series, span)];
    return;
  }
  // Where each date shows, from its anchor, on the anchor's clock.
  final lead = offsetOn(anchor, from);
  final length = lengthOn(from, to);
  final skipped = {
    for (final exdate in series.exdates) exdate.local,
    for (final part in item.changed) ?part.recurrenceId?.local,
  };
  // The rule as written: the one other apps read too.
  for (final wall in _instances(series, rule, span, lead, length)) {
    final instance = anchor.at(wall);
    final local = instance.local;
    final shownFrom = lead == Duration.zero
        ? local
        : anchor.at(wall.add(lead)).local;
    final shownTo = anchor.at(wall.add(lead + length)).local;
    if (!skipped.contains(local) &&
        spanOverlaps(shownFrom, shownTo, span.from, span.to)) {
      yield item.occurrenceOf(
        series,
        start: shownFrom,
        end: shownTo,
        recurrence: instance,
      );
    }
  }
  // A changed date that names no date of the series is kept, never shown.
  yield* [
    for (final part in item.changed)
      if (part.recurrenceId case final recurrence?)
        ?_shownAt(item, part, span, recurrence: recurrence),
  ];
}

/// [part] of [item] shown where it is written, as the date
/// [recurrence]; `null` where its times can't be read, it is cancelled,
/// or it is outside [span].
Occurrence? _shownAt<P extends ItemPart>(
  CalendarItem<P> item,
  P part,
  _Span span, {
  CalendarTime? recurrence,
}) => switch ((part.from, part.to)) {
  (final from?, final to?) when !part.cancelled && span.overlaps(from, to) =>
    item.occurrenceOf(
      part,
      start: from.local,
      end: to.local,
      recurrence: recurrence,
    ),
  _ => null,
};

/// How many steps from a series' start the library may walk before it
/// stops: its highest limit. A series past it shows up to there.
const _steps = RecurrenceIterator.absoluteMaxIterations;

/// The wall clocks of [series]' dates (its [rule] and its extra dates),
/// on its anchor's clock, that may overlap [span] where each shows
/// [lead] after its date for [length] (by the wall clocks). A rule the
/// library can't read gives only the anchor.
///
/// The library walks wall clocks: each goes in and comes out as a UTC
/// time holding the wall clock's fields, so no zone's clock change moves
/// it. Its types stay in this function.
List<DateTime> _instances(
  ItemPart series,
  String? rule,
  _Span span,
  Duration lead,
  Duration length,
) {
  final start = series.anchor!;
  final before = span.wallTo.subtract(lead);
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
  final after = span.wallFrom.subtract(lead + length);
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

/// Whether [item]'s series still has its date [date] (as the series
/// writes its anchor): the series repeats on it, and it is neither left
/// out nor cancelled.
bool hasOccurrenceAt(CalendarItem item, CalendarTime date) {
  if (item.changedAt(date) case final changed?) {
    return !changed.cancelled;
  }
  final at = date.local;
  final series = item.series;
  // Around where the date shows, from its anchor (a day either side, for
  // a clock change between them).
  final shown = switch ((series.anchor, series.from)) {
    (final anchor?, final from?) => at.add(offsetOn(anchor, from)),
    _ => at,
  };
  const near = Duration(days: 1);
  return _occurrencesOf(
    item,
    _Span(shown.subtract(near), shown.add(near)),
  ).any((each) => each.recurrence?.local == at);
}
