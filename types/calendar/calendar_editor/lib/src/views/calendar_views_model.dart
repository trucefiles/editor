import 'package:collection/collection.dart';
import 'package:flutter/material.dart' show ChangeNotifier, DateUtils;
import 'package:truce_calendar/truce_calendar.dart';

import '../day_clock.dart';
import 'health_days.dart';

/// One occurrence the views show, with the key of its calendar.
typedef ShownOccurrence<K> = ({K calendar, Occurrence occurrence});

/// The one owner of what the calendar views show: the [kind] of view,
/// the [range] it shows, the [shown] occurrences of its calendars around
/// that range, worked out once per change (never while building), the
/// cycle days of its health calendars ([health]), and [today], which
/// moves on at each midnight of [now]'s clock. Calendars are told
/// apart by their keys ([K]).
final class CalendarViewsModel<K> extends ChangeNotifier {
  CalendarViewsModel({
    required this._kind,
    required this._calendars,
    required DateTime Function() now,
  }) : _clock = DayClock(now) {
    _health = HealthDays.of(_calendars, today);
    _clock.addListener(_dayChanged);
  }

  final DayClock _clock;
  CalendarViewKind _kind;
  Map<K, Calendar> _calendars;
  ({DateTime from, DateTime to})? _range;
  ({DateTime from, DateTime to})? _window;
  List<ShownOccurrence<K>> _shown = const [];
  late HealthDays<K> _health;

  CalendarViewKind get kind => _kind;

  /// Today, at midnight.
  DateTime get today => _clock.today;

  /// The day in the middle of [range]: a month view shows the month it is
  /// in (its range has the weeks around it too).
  DateTime? get middle => switch (_range) {
    (:final from, :final to) => DateUtils.dateOnly(
      from.add(to.difference(from) ~/ 2),
    ),
    null => null,
  };

  /// The days shown: a month view's month, else [range].
  ({DateTime from, DateTime to})? get _days => switch ((_kind, middle)) {
    (CalendarViewKind.month, final middle?) => (
      from: DateTime(middle.year, middle.month),
      to: DateTime(middle.year, middle.month + 1),
    ),
    _ => _range,
  };

  /// The day Add event starts on: [today] if it shows, else the first day
  /// shown.
  DateTime get dayToAdd => switch (_days) {
    (:final from, :final to)
        when today.isBefore(DateUtils.dateOnly(from)) || !today.isBefore(to) =>
      DateUtils.dateOnly(from),
    _ => today,
  };

  /// The range shown, on this device's clock; `null` until it is told.
  ({DateTime from, DateTime to})? get range => _range;

  /// The occurrences of the calendars by start, in a window around
  /// [range]: its months and one month on each side. The views get the
  /// pages next to the one shown (and a schedule its scrolled-to part as
  /// the range) from it too, so nothing they still show goes empty.
  List<ShownOccurrence<K>> get shown => _shown;

  /// The cycle days of its health calendars as of [today].
  HealthDays<K> get health => _health;

  /// Shows the view [kind].
  void showKind(CalendarViewKind kind) {
    if (kind == _kind) return;
    _kind = kind;
    notifyListeners();
  }

  /// Shows [from] to [to].
  void showRange(DateTime from, DateTime to) {
    if (_range == (from: from, to: to)) return;
    _range = (from: from, to: to);
    if (_window case (from: final start, to: final end)
        when !from.isBefore(start) && !to.isAfter(end)) {
      return notifyListeners();
    }
    _window = (
      from: DateTime(from.year, from.month - 1),
      to: DateTime(to.year, to.month + 2),
    );
    _update();
  }

  /// Shows [calendars], each as read now; calendars that show the same
  /// days (e.g. only renamed) are kept without working them out again.
  void showCalendars(Map<K, Calendar> calendars) {
    final same = const MapEquality<Object?, Calendar>(values: _SameDays())
        .equals(calendars, _calendars);
    _calendars = calendars;
    if (same) return;
    _health = HealthDays.of(calendars, today);
    _update();
  }

  void _dayChanged() {
    _health = HealthDays.of(_calendars, today);
    notifyListeners();
  }

  @override
  void dispose() {
    _clock
      ..removeListener(_dayChanged)
      ..dispose();
    super.dispose();
  }

  void _update() {
    final window = _window;
    _shown = window == null
        ? const []
        : occurrencesOf(_calendars, window.from, window.to);
    notifyListeners();
  }
}

/// Calendars equal when they show the same days
/// ([Calendar.showsSameDaysAs]).
final class _SameDays implements Equality<Calendar> {
  const _SameDays();

  @override
  bool equals(Calendar a, Calendar b) => a.showsSameDaysAs(b);

  @override
  int hash(Calendar calendar) => identityHashCode(calendar.units);

  @override
  bool isValidKey(Object? o) => o is Calendar;
}
