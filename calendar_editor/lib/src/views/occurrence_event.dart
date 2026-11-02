import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../ui/occurrence_draft.dart';
import 'calendar_views_model.dart';

/// One [occurrence] as kalender shows it, with the key of its
/// [calendar]: kalender's own way to carry an app's data on an event.
final class OccurrenceEvent<K> extends KalenderEvent {
  OccurrenceEvent(
    this.calendar,
    this.occurrence, {
    required bool movable,
    DateTime? start,
    DateTime? end,
  }) : super(
         start: start ?? occurrence.start,
         // A broken end before the start shows as no length.
         end: _notBefore(end ?? occurrence.end, start ?? occurrence.start),
         isAllDay: occurrence.allDay,
         interaction: movable
             ? EventInteraction.allowAll()
             : EventInteraction.allowNone(),
       );

  final K calendar;
  final Occurrence occurrence;

  /// The tile's new times while it is dragged; the occurrence stays.
  @override
  OccurrenceEvent<K> copyWithData({
    required DateTime start,
    required DateTime end,
  }) => OccurrenceEvent(
    calendar,
    occurrence,
    movable: interaction.allowRescheduling,
    start: start,
    end: end,
  );

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

/// [shown] as kalender events; dragged only if [movable].
List<OccurrenceEvent<K>> eventsOf<K>(
  List<ShownOccurrence<K>> shown, {
  required bool movable,
}) => [
  for (final (:calendar, :occurrence) in shown)
    OccurrenceEvent(calendar, occurrence, movable: movable),
];

/// The edit that moves [occurrence] alone to [start] up to [end] (where a
/// drag or a resize let go): a single event changes, one of a series
/// becomes a changed one; its times keep their kind (a New York event
/// stays in New York, a day stays a day, at least one day long).
CalendarEdit Function(DateTime at) movedTo(
  Occurrence occurrence,
  DateTime start,
  DateTime end,
) {
  final draft = occurrenceDraft(occurrence);
  final newStart = draft.start.sameKindAt(start);
  final newEnd = switch (draft.end.sameKindAt(end)) {
    final AllDay day when !day.wall.isAfter(newStart.wall) => AllDay(
      newStart.wall.add(const Duration(days: 1)),
    ),
    final end => end,
  };
  final moved = draft.occurrenceAt(newStart, newEnd);
  final uid = occurrence.event.uid;
  return switch (occurrence.recurrence) {
    final one? => (at) => ChangeOccurrence(uid, one, moved, at: at),
    null => (at) => ChangeSeries(uid, moved, at: at),
  };
}
