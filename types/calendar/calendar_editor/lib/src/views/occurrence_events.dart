import 'dart:math' show max;

import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'changed_calendars.dart';
import 'occurrence_event.dart';

/// The occurrences of the shown calendars (by key, [K]) as kalender asks
/// for them: kalender asks for each page's range as it builds the page,
/// and each month of each calendar is worked out the first time a range
/// touches it, then kept until that calendar changes. Paging adds only
/// months not seen yet and tells no one; only [showCalendars] does.
///
/// Each occurrence is held once: by the first month it touches that was
/// worked out, so one that spans months shows once in each of them.
///
/// It is its store's only writer: kalender only asks, and the views add
/// and remove nothing through the writers it inherits.
final class OccurrenceEvents<K> extends DefaultEventsController {
  /// [deviceZone] tells this device's time zone apart (by default as
  /// kalender does): what is worked out holds only in the zone it was
  /// worked out in.
  OccurrenceEvents(this._calendars, {String Function() deviceZone = _zoneNow})
    : _deviceZone = deviceZone,
      _zone = deviceZone();

  Map<K, Calendar> _calendars;
  final String Function() _deviceZone;
  String _zone;

  /// Per calendar, the first days of the months worked out.
  final _months = <K, Set<DateTime>>{};

  /// Shows [calendars], each as read now: the ones that show other days
  /// than before (or came or went) are dropped and worked out again as
  /// kalender asks; the others keep their events.
  void showCalendars(Map<K, Calendar> calendars) {
    final changed = changedCalendars(_calendars, calendars);
    _calendars = calendars;
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
    _followDeviceZone();
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

  /// Forgets all that was worked out once the device is in another time
  /// zone: its times on the device clock, and its months, moved. kalender
  /// shows the zone change by asking again, so this tells no one.
  void _followDeviceZone() {
    final zone = _deviceZone();
    if (zone == _zone) return;
    _zone = zone;
    eventStore.clear();
    _months.clear();
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

/// This device's time zone now, as kalender tells it apart.
String _zoneNow() {
  final now = DateTime.now();
  return '${now.timeZoneName} ${now.timeZoneOffset}';
}

DateTime _nextMonth(DateTime month) => DateTime(month.year, month.month + 1);
