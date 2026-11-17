import '../model/calendar.dart';
import '../model/calendar_item.dart';
import '../model/calendar_unit.dart';
import '../recurrence/occurrences.dart';
import 'calendar_edit.dart';

/// What an edit names that is no longer in the calendar.
enum GoneMeanwhile {
  /// The whole event (e.g. deleted on another device).
  event,

  /// The one date of a repeating event (e.g. the series moved or that
  /// date was deleted on another device).
  eventDate,

  /// The whole task.
  task,

  /// The one date of a repeating task.
  taskDate,
}

/// [edit] as it lands on [calendar] now: what the user typed is never
/// lost. A change of an item that is gone, or of a date its series no
/// longer has, becomes the new item [newUid] as the user drafted it, and
/// says what was [gone]; a new date of a series doesn't repeat. A check of
/// a task or date that is gone lands as no edit (`null`), and says what
/// was gone. Other edits stay as they are (a delete of something gone
/// changes nothing).
({CalendarEdit? edit, GoneMeanwhile? gone}) landing(
  Calendar calendar,
  CalendarEdit edit, {
  required String newUid,
}) {
  final gone = _goneOf(calendar, edit);
  return (
    edit: switch ((edit, gone)) {
      (_, null) => edit,
      (ChangeSeries(:final draft, :final at), _) => AddItem(
        newUid,
        draft,
        at: at,
      ),
      (ChangeOccurrence(:final draft, :final at), _) => AddItem(
        newUid,
        draft.single,
        at: at,
      ),
      (CheckTask(), _) => null,
      _ => edit,
    },
    gone: gone,
  );
}

/// What [edit] changes that is gone from [calendar], if anything.
GoneMeanwhile? _goneOf(Calendar calendar, CalendarEdit edit) {
  final (date, mustBeThere) = switch (edit) {
    ChangeSeries() => (null, true),
    ChangeOccurrence(:final occurrence) => (occurrence, true),
    CheckTask(:final date) => (date, true),
    AddItem() || DeleteOccurrence() || DeleteItem() => (null, false),
  };
  if (!mustBeThere) return null;
  final task = edit.key.component == 'VTODO';
  return switch (_there(calendar, edit.key)) {
    null => task ? GoneMeanwhile.task : GoneMeanwhile.event,
    final item when date != null =>
      hasOccurrenceAt(item, date)
          ? null
          : (task ? GoneMeanwhile.taskDate : GoneMeanwhile.eventDate),
    _ => null,
  };
}

/// The item [key] if it is in [calendar], not deleted or cancelled.
CalendarItem? _there(Calendar calendar, UidKey key) =>
    switch (calendar.itemOf(key)) {
      final item? when !item.series.cancelled => item,
      _ => null,
    };
