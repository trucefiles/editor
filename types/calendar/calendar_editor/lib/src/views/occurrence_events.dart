import 'dart:math' show max;

import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'occurrence_event.dart';

/// The occurrences of the shown calendars (by key, [K]) as kalender asks
/// for them: kalender asks for each page's range as it builds the page,
/// and each month of each calendar is worked out the first time a range
/// touches it, then kept until that calendar changes. Paging adds only
/// months not seen yet and tells no one; only [showCalendars] does.
///
/// Each occurrence is held once: by the first month it touches that was
/// worked out, so one that spans months shows once in each of them.
final class OccurrenceEvents<K> extends DefaultEventsController {
  OccurrenceEvents(this._calendars);

  Map<K, Calendar> _calendars;

  /// Per calendar, the first days of the months worked out.
  final _months = <K, Set<DateTime>>{};

  /// Shows [calendars], each as read now: the ones that show other days
  /// than before (or came or went) are dropped and worked out again as
  /// kalender asks; the others keep their events.
  void showCalendars(Map<K, Calendar> calendars) {
    final before = _calendars;
    _calendars = calendars;
    final changed = {
      for (final key in {...before.keys, ...calendars.keys})
        if (!_sameDays(before[key], calendars[key])) key,
    };
    if (changed.isEmpty) return;
    eventStore.removeWhere(
      (_, event) => changed.contains((event as OccurrenceEvent<K>).calendar),
    );
    changed.forEach(_months.remove);
    notifyListeners();
  }

  /// kalender's ask, answered after the months of [range] are worked out.
  /// It asks while it builds and listens, so working them out tells no
  /// one.
  @override
  Iterable<KalenderEvent> eventsInRange(
    FloatingDateTimeRange range, {
    required MultiDayRule multiDayRule,
    bool includeMultiDayEvents = true,
    bool includeDayEvents = true,
    Location? location,
  }) {
    final shown = range.forLocation(location: location);
    for (final month in _monthsOf(shown.start, shown.end)) {
      for (final MapEntry(:key, :value) in _calendars.entries) {
        _workOut(key, value, month);
      }
    }
    return super.eventsInRange(
      range,
      multiDayRule: multiDayRule,
      includeMultiDayEvents: includeMultiDayEvents,
      includeDayEvents: includeDayEvents,
      location: location,
    );
  }

  /// Adds the occurrences of [calendar] (keyed [key]) in [month], but not
  /// those another month already worked out holds.
  void _workOut(K key, Calendar calendar, DateTime month) {
    final done = _months.putIfAbsent(key, () => {});
    if (done.contains(month)) return;
    final end = _nextMonth(month);
    for (final occurrence in occurrences(calendar, month, end)) {
      if (!_heldBy(done, occurrence)) {
        eventStore.addNewEvent(OccurrenceEvent(key, occurrence));
      }
    }
    done.add(month);
  }
}

bool _sameDays(Calendar? a, Calendar? b) => switch ((a, b)) {
  (null, null) => true,
  (final a?, final b?) => a.showsSameDaysAs(b),
  _ => false,
};

/// Whether one of the months [done] overlaps [occurrence].
bool _heldBy(Set<DateTime> done, Occurrence occurrence) =>
    _monthsOf(occurrence.start, occurrence.end).any(
      (month) =>
          done.contains(month) && occurrence.overlaps(month, _nextMonth(month)),
    );

/// The first days of the months [from] to [to] touches; [from]'s month at
/// least.
List<DateTime> _monthsOf(DateTime from, DateTime to) {
  final first = DateTime(from.year, from.month);
  final endsOnMonthStart = to == DateTime(to.year, to.month);
  final count =
      (to.year - first.year) * 12 +
      to.month -
      first.month +
      (endsOnMonthStart ? 0 : 1);
  return List.generate(
    max(count, 1),
    (index) => DateTime(first.year, first.month + index),
  );
}

DateTime _nextMonth(DateTime month) => DateTime(month.year, month.month + 1);
