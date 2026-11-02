import '../model/calendar_time.dart';
import '../recurrence/occurrences.dart';
import 'calendar_edit.dart';
import 'event_draft.dart';

/// What [occurrence] alone is, to edit it: a changed one as it is, a
/// single event as it is, else the series at the occurrence's time (it
/// doesn't repeat).
EventDraft occurrenceDraft(Occurrence occurrence) =>
    switch (occurrence.recurrence) {
      final one? => EventDraft.at(occurrence.event, one),
      null => EventDraft.of(occurrence.part),
    };

/// The edit that moves [occurrence] alone to [start] up to [end] (on this
/// device's clock): a single event changes, one of a series becomes a
/// changed one; its times keep their kind (a New York event stays in New
/// York, a day stays a day, at least one day long).
CalendarEdit Function(DateTime at) occurrenceMovedTo(
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
    final one? => (at) => ChangeOccurrence(
      uid,
      one,
      moved,
      from: draft,
      at: at,
    ),
    null => (at) => ChangeSeries(uid, moved, from: draft, at: at),
  };
}
