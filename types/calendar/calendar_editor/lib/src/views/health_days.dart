import 'package:truce_calendar/truce_calendar.dart';

/// How a day shows in a health calendar's cycle: a period day, a day the
/// next period likely falls on, a likely fertile day.
typedef CycleDay = ({bool period, bool likelyPeriod, bool fertile});

/// The cycle days of health calendars that have a period recorded,
/// worked out once from their entries as of [today]: what the month view
/// shades, and each one's [cycles] for the insights line.
final class HealthDays<K> {
  /// Of [calendars] (by key), as of [today].
  factory HealthDays.of(Map<K, Calendar> calendars, DateTime today) {
    final periods = {
      for (final MapEntry(:key, value: calendar) in calendars.entries)
        if (calendar.isHealth)
          if ({for (final day in periodDays(calendar)) _key(day)}
              case final days when days.isNotEmpty)
            key: days,
    };
    final cycles = {
      for (final MapEntry(:key, value: days) in periods.entries)
        key: ?predictCycle(days, today),
    };
    return HealthDays._(
      {for (final days in periods.values) ...days},
      {for (final cycle in cycles.values) ...cycle.nextPeriod.map(_key)},
      {for (final cycle in cycles.values) ...cycle.fertileWindow.map(_key)},
      cycles,
    );
  }

  HealthDays._(this._periods, this._likely, this._fertile, this.cycles);

  /// No health calendar with a period.
  HealthDays.none() : this._({}, {}, {}, {});

  final Set<DateTime> _periods;
  final Set<DateTime> _likely;
  final Set<DateTime> _fertile;

  /// The cycle each health calendar with periods is in, by its key.
  final Map<K, CyclePrediction> cycles;

  /// Whether any day shows as a cycle day: only then the views explain
  /// the marks.
  bool get any => _periods.isNotEmpty;

  /// How [day] shows.
  CycleDay of(DateTime day) {
    final key = _key(day);
    final period = _periods.contains(key);
    return (
      period: period,
      likelyPeriod: !period && _likely.contains(key),
      fertile: _fertile.contains(key),
    );
  }

  /// A day as health days are keyed: its UTC midnight.
  static DateTime _key(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day);
}
