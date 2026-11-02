import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart' show ChangeNotifier, DateUtils;
import 'package:truce_calendar/truce_calendar.dart';

import 'calendar_view_kind.dart';

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
    required this._now,
  }) {
    _today = _nextToday();
  }

  final DateTime Function() _now;
  late DateTime _today;
  Timer? _midnight;
  CalendarViewKind _kind;
  Map<K, Calendar> _calendars;
  ({DateTime from, DateTime to})? _range;
  List<ShownOccurrence<K>> _shown = const [];

  CalendarViewKind get kind => _kind;

  /// Today, at midnight.
  DateTime get today => _today;

  /// The day Add event starts on: [today] if it shows, else the first day
  /// shown.
  DateTime get dayToAdd => switch (_range) {
    (:final from, :final to)
        when _today.isBefore(DateUtils.dateOnly(from)) ||
            !_today.isBefore(to) =>
      DateUtils.dateOnly(from),
    _ => _today,
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

  /// Today, and a wake at the next midnight to move it on.
  DateTime _nextToday() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    _midnight?.cancel();
    _midnight = Timer(
      DateTime(today.year, today.month, today.day + 1).difference(now),
      () {
        _today = _nextToday();
        notifyListeners();
      },
    );
    return today;
  }

  @override
  void dispose() {
    _midnight?.cancel();
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
