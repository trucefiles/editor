import 'package:flutter/widgets.dart' show TextDirection;
import 'package:kalender/kalender.dart';

/// kalender's month layout with each day's events in the order a day is
/// read: events that last whole days or run over several days first,
/// longest first so their bars keep one row, then timed events by start.
final class MonthOrder extends MultiDayLayoutStrategy {
  const MonthOrder();

  @override
  MultiDayLayoutFrame generateFrame({
    required FloatingDateTimeRange visibleRange,
    required List<KalenderEvent> events,
    required TextDirection textDirection,
    required Location? location,
    required MultiDayLayoutFrameCache? cache,
  }) => defaultMultiDayFrameGenerator(
    visibleRange: visibleRange,
    events: events,
    textDirection: textDirection,
    location: location,
    cache: cache,
    eventComparator: (a, b) => _compare(a, b, location),
  );

  @override
  bool operator ==(Object other) => other is MonthOrder;

  @override
  int get hashCode => (MonthOrder).hashCode;
}

int _compare(KalenderEvent a, KalenderEvent b, Location? location) =>
    switch ((_takesDays(a, location), _takesDays(b, location))) {
      (true, false) => -1,
      (false, true) => 1,
      (true, true) => switch (b.duration.compareTo(a.duration)) {
        0 => a.start.compareTo(b.start),
        final longerFirst => longerFirst,
      },
      (false, false) => switch (a.start.compareTo(b.start)) {
        0 => b.duration.compareTo(a.duration),
        final earlierFirst => earlierFirst,
      },
    };

/// Whether [event] shows as a bar of whole days: all day, or over more
/// than one day.
bool _takesDays(KalenderEvent event, Location? location) =>
    event.isAllDay || event.datesSpanned(location: location).length > 1;
