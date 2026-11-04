import '../model/calendar.dart';
import '../model/calendar_event.dart';
import '../recurrence/occurrences.dart';
import 'calendar_edit.dart';

/// What an edit names that is no longer in the calendar.
enum GoneMeanwhile {
  /// The whole event (e.g. deleted on another device).
  event,

  /// The one date of a repeating event (e.g. the series moved or that
  /// date was deleted on another device).
  date,
}

/// [edit] as it lands on [calendar] now: what the user typed is never
/// lost. A change of an event that is gone, or of a date its series no
/// longer has, becomes the new event [newUid] as the user drafted it, and
/// says what was [gone]; a new date of a series doesn't repeat. Other
/// edits stay as they are (a delete of something gone changes nothing).
({CalendarEdit edit, GoneMeanwhile? gone}) landing(
  Calendar calendar,
  CalendarEdit edit, {
  required String newUid,
}) {
  final gone = _goneOf(calendar, edit);
  return (
    edit: switch ((edit, gone)) {
      (_, null) => edit,
      (ChangeSeries(:final draft, :final at), _) => AddEvent(
        newUid,
        draft,
        at: at,
      ),
      (ChangeOccurrence(:final draft, :final at), _) => AddEvent(
        newUid,
        draft.occurrenceAt(draft.start, draft.end),
        at: at,
      ),
      _ => edit,
    },
    gone: gone,
  );
}

/// What [edit] changes that is gone from [calendar], if anything.
GoneMeanwhile? _goneOf(Calendar calendar, CalendarEdit edit) => switch (edit) {
  ChangeSeries(:final uid) when _there(calendar, uid) == null =>
    GoneMeanwhile.event,
  ChangeOccurrence(:final uid, :final occurrence) => switch (_there(
    calendar,
    uid,
  )) {
    null => GoneMeanwhile.event,
    final event =>
      hasOccurrenceAt(event, occurrence) ? null : GoneMeanwhile.date,
  },
  _ => null,
};

/// The event [uid] if it is in [calendar], not deleted or cancelled.
CalendarEvent? _there(Calendar calendar, String uid) =>
    switch (calendar.eventOf(uid)) {
      final event? when !event.series.cancelled => event,
      _ => null,
    };
