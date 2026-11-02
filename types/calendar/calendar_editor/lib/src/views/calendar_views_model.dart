import 'package:collection/collection.dart';
import 'package:flutter/material.dart' show ChangeNotifier, DateUtils;
import 'package:truce_calendar/truce_calendar.dart';

import '../day_clock.dart';

/// One occurrence the views show, with the key of its calendar.
typedef ShownOccurrence<K> = ({K calendar, Occurrence occurrence});

/// The one owner of what the calendar views show: the [kind] of view,
/// the [range] it shows, the [shown] occurrences of its calendars in that
/// range, worked out once per change (never while building), and [today],
/// which moves on at each midnight of [now]'s clock. Calendars are told
/// apart by their keys ([K]).
final class CalendarViewsModel<K> extends ChangeNotifier {
  CalendarViewsModel({
    required this._kind,
    required this._calendars,
    required DateTime Function() now,
  }) : _clock = DayClock(now) {
    _clock.addListener(notifyListeners);
  }

  final DayClock _clock;
  CalendarViewKind _kind;
  Map<K, Calendar> _calendars;
  ({DateTime from, DateTime to})? _range;
  List<ShownOccurrence<K>> _shown = const [];

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

  /// The occurrences of the calendars in [range], by start.
  List<ShownOccurrence<K>> get shown => _shown;

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
    _update();
  }

  /// Shows [calendars], each as read now; the same calendars change
  /// nothing.
  void showCalendars(Map<K, Calendar> calendars) {
    if (const MapEquality<Object?, Calendar>(values: IdentityEquality())
        .equals(calendars, _calendars)) {
      return;
    }
    _calendars = calendars;
    _update();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _update() {
    final range = _range;
    _shown = range == null
        ? const []
        : occurrencesOf(_calendars, range.from, range.to);
    notifyListeners();
  }
}
