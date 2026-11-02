import 'package:rrule/rrule.dart';

import '../model/calendar.dart';
import '../model/calendar_event.dart';
import '../model/calendar_time.dart';

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
  if (rule == null || series.recurrenceId != null) {
    if (_overlaps(start.local, end.local, from, to)) {
      yield Occurrence(event, series, start: start.local, end: end.local);
    }
    return;
  }
  final length = end.wall.difference(start.wall);
  final skipped = {
    for (final exdate in series.exdates) exdate.local,
    for (final part in event.changed) ?part.recurrenceId?.local,
  };
  // The rule as written: the one other apps read too.
  for (final wall in _instances(rule, start.wall, from, to, length)) {
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

/// The wall clocks of [rule]'s occurrences from [start] that may overlap
/// [from] to [to]: a day more on each side, for time zones. None if it
/// starts after them; a rule the library can't read gives none but the
/// first.
Iterable<DateTime> _instances(
  String rule,
  DateTime start,
  DateTime from,
  DateTime to,
  Duration length,
) {
  const margin = Duration(days: 1);
  final before = _wallOf(to).add(margin);
  if (start.isAfter(before)) return const [];
  final RecurrenceRule recurrence;
  try {
    recurrence = RecurrenceRule.fromString('RRULE:$rule');
  } on FormatException {
    // The library reports a rule it can't read only by throwing.
    return [start];
  }
  final after = _wallOf(from).subtract(length + margin);
  return recurrence.getInstances(
    start: start,
    after: after.isAfter(start) ? after : null,
    includeAfter: true,
    before: before,
  );
}

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
