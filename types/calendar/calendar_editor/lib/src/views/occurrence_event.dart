import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';

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
         interaction: _stretches(occurrence)
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

/// Whether [occurrence] can be stretched: a health entry is on one day,
/// and a task is due at one time; both move, but don't stretch.
bool _stretches(Occurrence occurrence) => switch (occurrence) {
  EventOccurrence(part: EventPart(health: null)) => true,
  EventOccurrence() || TaskOccurrence() => false,
};

DateTime _notBefore(DateTime end, DateTime start) =>
    end.isBefore(start) ? start : end;
