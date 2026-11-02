import 'package:collection/collection.dart';

import '../model/calendar.dart';
import '../model/calendar_event.dart';
import '../model/health_entry.dart';

/// A guess at the cycle from the period days written so far: derived,
/// never stored. An estimate only, not for contraception.
final class CyclePrediction {
  const CyclePrediction({
    required this.lastStart,
    required this.cycleLength,
    required this.periodLength,
  });

  /// The first day of the latest period.
  final DateTime lastStart;

  /// Days from one period's start to the next.
  final int cycleLength;

  /// Days a period lasts.
  final int periodLength;

  /// When the next period likely starts.
  DateTime get nextStart => _days(lastStart, cycleLength);

  /// The days the next period likely lasts, from [nextStart].
  List<DateTime> get nextPeriod => [
    for (final day in Iterable<int>.generate(periodLength))
      _days(nextStart, day),
  ];

  /// The likely day of ovulation: two weeks before the next period.
  DateTime get ovulation => _days(nextStart, -14);

  /// The likely fertile days: five before ovulation to one after.
  List<DateTime> get fertileWindow => [
    for (final day in Iterable<int>.generate(7)) _days(ovulation, day - 5),
  ];

  /// Which day of the cycle [today] is, the period's first being 1.
  int dayOfCycle(DateTime today) =>
      _dayOf(today).difference(lastStart).inDays + 1;

  /// Days from [today] until [nextStart]; negative once it is late.
  int daysUntilNext(DateTime today) =>
      nextStart.difference(_dayOf(today)).inDays;
}

/// The cycle [days] (each a day with a period entry) say, as of [today]:
/// a period starts on the first day of each run of period days (a gap of
/// two days or more without one starts a new one); the cycle is the mean of the last
/// six cycles (else 28 days), a period the mean of the last six runs
/// (else 5 days). `null` before any period is written.
CyclePrediction? predictCycle(Iterable<DateTime> days, DateTime today) {
  final sorted = {
    for (final day in days)
      if (!_dayOf(day).isAfter(_dayOf(today))) _dayOf(day),
  }.toList()..sort();
  if (sorted.isEmpty) return null;
  // Runs of days with gaps of at most one day, in one pass.
  final runs = <List<DateTime>>[];
  for (final day in sorted) {
    if (runs.lastOrNull case final run?
        when day.difference(run.last).inDays <= 2) {
      run.add(day);
    } else {
      runs.add([day]);
    }
  }
  final starts = [for (final run in runs) run.first];
  final cycles = [
    for (final (index, start) in starts.indexed.skip(1))
      start.difference(starts[index - 1]).inDays,
  ];
  // The latest run may still go on, so it says nothing of the length yet.
  final lengths = [
    for (final run in runs.length > 1 ? runs.take(runs.length - 1) : runs)
      run.last.difference(run.first).inDays + 1,
  ];
  return CyclePrediction(
    lastStart: starts.last,
    cycleLength: _meanOfLast(cycles) ?? 28,
    periodLength: _meanOfLast(lengths) ?? 5,
  );
}

/// The days of [calendar] with a period entry.
Iterable<DateTime> periodDays(Calendar calendar) => [
  for (final event in calendar.events)
    if (event.series case final part
        when part.health is Period && !part.deleted && !part.cancelled)
      ?part.start?.wall,
];

/// The rounded mean of the last six of [values]; `null` if none.
int? _meanOfLast(List<int> values) {
  final last = values.skip(values.length > 6 ? values.length - 6 : 0);
  if (last.isEmpty) return null;
  return (last.reduce((a, b) => a + b) / last.length).round();
}

DateTime _dayOf(DateTime time) => DateTime.utc(time.year, time.month, time.day);

DateTime _days(DateTime day, int count) =>
    DateTime.utc(day.year, day.month, day.day + count);

/// The health entries of [calendar] by their day (a UTC midnight), each
/// day's in file order; deleted and cancelled ones left out.
Map<DateTime, List<CalendarEvent>> healthByDay(Calendar calendar) => groupBy([
  for (final event in calendar.events)
    if (event.series case final part
        when part.health != null &&
            !part.deleted &&
            !part.cancelled &&
            part.start != null)
      event,
], (CalendarEvent event) => _dayOf(event.series.start!.wall));
