import 'package:truce_calendar/truce_calendar.dart';

/// What [occurrence] alone is, to edit it: a changed one as it is, a
/// single event as it is, else the series at the occurrence's time (it
/// doesn't repeat).
EventDraft occurrenceDraft(Occurrence occurrence) {
  final part = occurrence.part;
  final draft = EventDraft.of(part);
  final one = occurrence.recurrence;
  if (part.recurrenceId != null || one == null) return draft;
  final length = draft.end.wall.difference(draft.start.wall);
  return draft.occurrenceAt(one, one.at(one.wall.add(length)));
}
