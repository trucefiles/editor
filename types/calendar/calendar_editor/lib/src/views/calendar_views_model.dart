import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:truce_calendar/truce_calendar.dart';

import '../day_clock.dart';
import 'health_days.dart';

/// A range of time on this device's clock.
typedef ShownRange = ({DateTime from, DateTime to});

/// The one owner of what the calendar views show around their events:
/// the [kind] of view, the [range] it shows, the cycle days of its health
/// calendars ([health]), and [today], which moves on at each midnight of
/// [now]'s clock. It tells a change of [range] on its own, as paging
/// changes nothing else; its listeners hear the rest. Calendars are told
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
  final _range = ValueNotifier<ShownRange?>(null);
  late HealthDays<K> _health;

  CalendarViewKind get kind => _kind;

  /// Today, at midnight.
  DateTime get today => _clock.today;

  /// The day in the middle of [range]: a month view shows the month it is
  /// in (its range has the weeks around it too).
  DateTime? get middle => switch (_range.value) {
    (:final from, :final to) => DateUtils.dateOnly(
      from.add(to.difference(from) ~/ 2),
    ),
    null => null,
  };

  /// The days shown: a month view's month, else [range].
  ShownRange? get _days => switch ((_kind, middle)) {
    (CalendarViewKind.month, final middle?) => (
      from: DateTime(middle.year, middle.month),
      to: DateTime(middle.year, middle.month + 1),
    ),
    _ => _range.value,
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
  ValueListenable<ShownRange?> get range => _range;

  /// The cycle days of its health calendars as of [today].
  HealthDays<K> get health => _health;

  /// Shows the view [kind].
  void showKind(CalendarViewKind kind) {
    if (kind == _kind) return;
    _kind = kind;
    notifyListeners();
  }

  /// Shows [from] to [to].
  void showRange(DateTime from, DateTime to) =>
      _range.value = (from: from, to: to);

  /// Shows [calendars], each as read now; calendars that show the same
  /// days (e.g. only renamed) are kept without working them out again.
  void showCalendars(Map<K, Calendar> calendars) {
    final same = const MapEquality<Object?, Calendar>(values: _SameDays())
        .equals(calendars, _calendars);
    _calendars = calendars;
    if (same) return;
    _health = HealthDays.of(calendars, today);
    notifyListeners();
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
    _range.dispose();
    super.dispose();
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
