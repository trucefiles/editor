import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'calendar_views_model.dart';

/// One [occurrence] as kalender shows it, with the key of its
/// [calendar]: kalender's own way to carry an app's data on an event.
final class OccurrenceEvent<K> extends KalenderEvent {
  OccurrenceEvent(
    this.calendar,
    this.occurrence, {
    DateTime? start,
    DateTime? end,
  }) : super(
         start: start ?? occurrence.start,
         // A broken end before the start shows as no length.
         end: _notBefore(end ?? occurrence.end, start ?? occurrence.start),
         isAllDay: occurrence.allDay,
         // A health entry is on one day: it moves, but doesn't stretch.
         interaction: occurrence.part.health == null
             ? EventInteraction.allowAll()
             : EventInteraction(allowStartResize: false, allowEndResize: false),
       );

  final K calendar;
  final Occurrence occurrence;

  /// The tile's new times while it is dragged; the occurrence stays.
  @override
  OccurrenceEvent<K> copyWithData({
    required DateTime start,
    required DateTime end,
  }) => OccurrenceEvent(calendar, occurrence, start: start, end: end);

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is OccurrenceEvent<K> &&
      other.calendar == calendar &&
      other.occurrence == occurrence;

  @override
  int get hashCode => Object.hash(super.hashCode, calendar, occurrence);
}

DateTime _notBefore(DateTime end, DateTime start) =>
    end.isBefore(start) ? start : end;

/// [shown] as kalender events (whether they can be dragged is the
/// views' one rule).
List<OccurrenceEvent<K>> eventsOf<K>(List<ShownOccurrence<K>> shown) => [
  for (final (:calendar, :occurrence) in shown)
    OccurrenceEvent(calendar, occurrence),
];
