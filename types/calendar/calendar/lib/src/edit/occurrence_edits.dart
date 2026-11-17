import '../model/calendar_time.dart';
import '../recurrence/occurrences.dart';
import 'calendar_edit.dart';
import 'item_draft.dart';

/// What [occurrence] alone is, to edit it: a changed one as it is, a
/// single item as it is, else the series at that date (it doesn't
/// repeat).
ItemDraft occurrenceDraft(Occurrence occurrence) =>
    switch (occurrence.recurrence) {
      final one? => ItemDraft.at(occurrence.item, one),
      null => ItemDraft.of(occurrence.part),
    };

/// The edit that moves [occurrence] alone to [start] up to [end] (on this
/// device's clock), where the user dragged it: a single item changes, a
/// date of a series becomes a changed one. Its times keep their kind (a
/// New York event stays in New York, a day stays a day, at least one day
/// long); a task becomes due at [end] (a day: on [start]'s), its start
/// moved along.
CalendarEdit Function(DateTime at) occurrenceMovedTo(
  Occurrence occurrence,
  DateTime start,
  DateTime end,
) {
  final draft = occurrenceDraft(occurrence);
  final moved = switch (draft) {
    EventDraft() => _eventMoved(draft, start, end),
    TaskDraft(:final due?) => draft.withDue(
      due is AllDay ? due.sameKindAt(start) : due.sameKindAt(end),
    ),
    TaskDraft() => draft,
  };
  final uid = occurrence.item.uid;
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

/// [draft] moved to [start] up to [end], its times of their kind.
EventDraft _eventMoved(EventDraft draft, DateTime start, DateTime end) {
  final newStart = draft.start.sameKindAt(start);
  final newEnd = switch (draft.end.sameKindAt(end)) {
    final AllDay day when !day.wall.isAfter(newStart.wall) => AllDay(
      newStart.wall.add(const Duration(days: 1)),
    ),
    final end => end,
  };
  return draft.occurrenceAt(newStart, newEnd);
}
