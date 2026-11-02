import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'calendar_view_kind.dart';

/// One occurrence the views show, with the key of its calendar.
typedef ShownOccurrence<K> = ({K calendar, Occurrence occurrence});

/// The one owner of what the calendar views show: the [kind] of view,
/// the [range] it shows, and the [shown] occurrences of its calendars in
/// that range, worked out once per change (never while building).
/// Calendars are told apart by their keys ([K]).
final class CalendarViewsModel<K> extends ChangeNotifier {
  CalendarViewsModel({required this._kind, required this._calendars});

  CalendarViewKind _kind;
  Map<K, Calendar> _calendars;
  ({DateTime from, DateTime to})? _range;
  List<ShownOccurrence<K>> _shown = const [];

  CalendarViewKind get kind => _kind;

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

  void _update() {
    final range = _range;
    _shown = range == null
        ? const []
        : occurrencesOf(_calendars, range.from, range.to);
    notifyListeners();
  }
}
