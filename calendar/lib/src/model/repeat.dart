import 'package:collection/collection.dart';

import '../read/content_line.dart';
import '../read/values.dart';
import 'calendar_time.dart';
import 'wall_on.dart';

/// How a series repeats, as its `RRULE` says.
sealed class Repeat {
  const Repeat();

  /// The rule as written for a series starting at [start], without
  /// `RRULE:`; its last day ([until]) written as [start] writes it, so a
  /// new start (e.g. a day turned into a time) keeps the same last day.
  String ruleFor(CalendarTime start);

  /// The last day it may come on, on the series' own clock, as a UTC
  /// midnight; `null` if it has none.
  DateTime? get until;

  /// Whether the rule picks its days itself (e.g. on Mondays), rather
  /// than going on from the start's day.
  bool get fixesDays;

  /// The repeat [rule] says for a series starting at [start]: a
  /// [SimpleRepeat] where the form can show it, else kept as it is.
  static Repeat of(String rule, CalendarTime start) =>
      SimpleRepeat._read(rule, start) ??
      OtherRepeat(rule, until: _untilOf(_partsOf(rule)['UNTIL'], start));
}

/// How often a [SimpleRepeat] comes.
enum Frequency { daily, weekly, monthly, yearly }

/// The days of the week, as rules name them.
enum Weekday { mo, tu, we, th, fr, sa, su }

/// A repeat the event form edits: every [interval] days, weeks (on
/// [days]), months (on the start's day) or years; until a day ([until])
/// or for a number of times ([count]), else for ever.
final class SimpleRepeat extends Repeat {
  const SimpleRepeat(
    this.frequency, {
    this.interval = 1,
    this.days = const {},
    this.until,
    this.count,
  });

  final Frequency frequency;
  final int interval;

  /// The days of a weekly repeat; empty: the start's day.
  final Set<Weekday> days;

  @override
  final DateTime? until;
  final int? count;

  @override
  bool get fixesDays => days.isNotEmpty;

  /// The parts a simple repeat may have.
  static const _parts = {'FREQ', 'INTERVAL', 'BYDAY', 'UNTIL', 'COUNT'};

  static SimpleRepeat? _read(String rule, CalendarTime start) {
    final parts = _partsOf(rule);
    final frequency = Frequency.values.firstWhereOrNull(
      (frequency) => frequency.name.toUpperCase() == parts['FREQ'],
    );
    final days = [
      for (final day
          in (parts['BYDAY'] ?? '').split(',').where((day) => day.isNotEmpty))
        Weekday.values.firstWhereOrNull(
          (weekday) => weekday.name.toUpperCase() == day,
        ),
    ];
    final interval = int.tryParse(parts['INTERVAL'] ?? '1');
    final until = _untilOf(parts['UNTIL'], start);
    if (frequency == null ||
        !parts.keys.every(_parts.contains) ||
        days.contains(null) ||
        (days.isNotEmpty && frequency != Frequency.weekly) ||
        interval == null ||
        interval < 1 ||
        (parts.containsKey('UNTIL') && until == null) ||
        (parts.containsKey('COUNT') && int.tryParse(parts['COUNT']!) == null)) {
      return null;
    }
    return SimpleRepeat(
      frequency,
      interval: interval,
      days: days.nonNulls.toSet(),
      until: until,
      count: int.tryParse(parts['COUNT'] ?? ''),
    );
  }

  /// [until] is written as [start] is (RFC 5545, 3.3.10): a day; the end
  /// of the day for a floating start; else the end of the day in
  /// [start]'s zone, in UTC, so other apps end on the same day.
  @override
  String ruleFor(CalendarTime start) => [
    'FREQ=${frequency.name.toUpperCase()}',
    if (interval != 1) 'INTERVAL=$interval',
    if (days.isNotEmpty)
      'BYDAY=${Weekday.values.where(days.contains).map((day) => day.name.toUpperCase()).join(',')}',
    if (until case final until?)
      'UNTIL=${timeLine('UNTIL', _endOfDay(until, start)).value}',
    if (count case final count?) 'COUNT=$count',
  ].join(';');

  @override
  bool operator ==(Object other) =>
      other is SimpleRepeat &&
      other.frequency == frequency &&
      other.interval == interval &&
      const SetEquality<Weekday>().equals(other.days, days) &&
      other.until == until &&
      other.count == count;

  @override
  int get hashCode => Object.hash(
    frequency,
    interval,
    const SetEquality<Weekday>().hash(days),
    until,
    count,
  );
}

/// The last moment of [day] as [start] writes an `UNTIL`: the day itself
/// for a day, its end for a floating time, else its end in [start]'s zone
/// in UTC.
CalendarTime _endOfDay(DateTime day, CalendarTime start) {
  final end = DateTime.utc(day.year, day.month, day.day, 23, 59, 59);
  return switch (start) {
    AllDay() => AllDay(day),
    Floating() => Floating(end),
    UtcTime() || Zoned() => UtcTime(start.at(end).local.toUtc()),
  };
}

/// The parts of [rule] by name, upper case.
Map<String, String> _partsOf(String rule) => {
  for (final part in rule.split(';'))
    if (part.split('=') case [final key, final value])
      key.trim().toUpperCase(): value.trim().toUpperCase(),
};

/// The day of an `UNTIL` value on [start]'s clock (see [wallOn]).
DateTime? _untilOf(String? value, CalendarTime start) {
  final until = value == null ? null : timeOf(ContentLine('UNTIL', value));
  if (until == null) return null;
  final day = wallOn(start, until);
  return DateTime.utc(day.year, day.month, day.day);
}

/// A rule the form doesn't edit: kept as written, shown as its text; only
/// its last day is written anew for a new start.
final class OtherRepeat extends Repeat {
  const OtherRepeat(this.rule, {this.until});

  /// The rule as written.
  final String rule;

  @override
  final DateTime? until;

  /// Whether it has a part that picks days, weeks or months.
  @override
  bool get fixesDays => _partsOf(rule).keys.any(
    const {
      'BYDAY',
      'BYMONTHDAY',
      'BYYEARDAY',
      'BYWEEKNO',
      'BYMONTH',
      'BYSETPOS',
    }.contains,
  );

  @override
  String ruleFor(CalendarTime start) => switch (until) {
    final until? => rule.replaceFirst(
      RegExp('UNTIL=[^;]*', caseSensitive: false),
      'UNTIL=${timeLine('UNTIL', _endOfDay(until, start)).value}',
    ),
    null => rule,
  };

  @override
  bool operator ==(Object other) => other is OtherRepeat && other.rule == rule;

  @override
  int get hashCode => rule.hashCode;
}
