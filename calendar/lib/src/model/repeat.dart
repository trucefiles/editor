import 'package:collection/collection.dart';

import '../read/values.dart';
import 'calendar_time.dart';

/// How a series repeats, as its `RRULE` says.
sealed class Repeat {
  const Repeat();

  /// The rule as written for a series starting at [start], without
  /// `RRULE:`.
  String ruleFor(CalendarTime start);

  /// The repeat [rule] says: a [SimpleRepeat] where the form can show it,
  /// else kept as it is.
  static Repeat of(String rule) =>
      SimpleRepeat._read(rule) ?? OtherRepeat(rule);
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

  /// The last day it may come on, as a UTC midnight.
  final DateTime? until;
  final int? count;

  /// The parts a simple repeat may have.
  static const _parts = {'FREQ', 'INTERVAL', 'BYDAY', 'UNTIL', 'COUNT'};

  static SimpleRepeat? _read(String rule) {
    final parts = {
      for (final part in rule.split(';'))
        if (part.split('=') case [final key, final value])
          key.trim().toUpperCase(): value.trim().toUpperCase(),
    };
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
    final until = _untilOf(parts['UNTIL']);
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

  /// The day of an `UNTIL` value, a day or a time.
  static DateTime? _untilOf(String? value) =>
      switch (RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(value ?? '')) {
        final match? => DateTime.utc(
          int.parse(match[1]!),
          int.parse(match[2]!),
          int.parse(match[3]!),
        ),
        null => null,
      };

  /// [until] is written as [start] is (RFC 5545, 3.3.10): a day, or the
  /// end of the day.
  @override
  String ruleFor(CalendarTime start) => [
    'FREQ=${frequency.name.toUpperCase()}',
    if (interval != 1) 'INTERVAL=$interval',
    if (days.isNotEmpty)
      'BYDAY=${Weekday.values.where(days.contains).map((day) => day.name.toUpperCase()).join(',')}',
    if (until case final until?)
      'UNTIL=${dayText(until)}${switch (start) {
        AllDay() => '',
        Floating() => 'T235959',
        UtcTime() || Zoned() => 'T235959Z',
      }}',
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

/// A rule the form doesn't edit: kept as written, shown as its text.
final class OtherRepeat extends Repeat {
  const OtherRepeat(this.rule);

  /// The rule as written.
  final String rule;

  @override
  String ruleFor(CalendarTime start) => rule;

  @override
  bool operator ==(Object other) => other is OtherRepeat && other.rule == rule;

  @override
  int get hashCode => rule.hashCode;
}
