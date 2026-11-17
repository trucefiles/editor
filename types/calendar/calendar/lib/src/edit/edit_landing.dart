import '../model/calendar.dart';
import '../model/calendar_item.dart';
import '../model/calendar_unit.dart';
import '../recurrence/occurrences.dart';
import 'calendar_edit.dart';

/// What an edit names that is no longer in the calendar.
enum GoneMeanwhile {
  /// The whole event or task (e.g. deleted on another device).
  item,

  /// The one date of a repeating event or task (e.g. the series moved or
  /// that date was deleted on another device).
  date,
}

/// What an edit named that is gone: of what [kind] of item, and [what].
typedef Gone = ({ItemKind kind, GoneMeanwhile what});

/// [edit] as it lands on [calendar] now: what the user typed is never
/// lost. A change of an item that is gone, or of a date its series no
/// longer has, becomes the new item [newUid] as the user drafted it, and
/// says what was [gone]; a new date of a series doesn't repeat. A check of
/// a task or date that is gone lands as no edit (`null`), and says what
/// was gone. Other edits stay as they are (a delete of something gone
/// changes nothing).
({CalendarEdit? edit, Gone? gone}) landing(
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
Gone? _goneOf(Calendar calendar, CalendarEdit edit) {
  final (date, mustBeThere) = switch (edit) {
    ChangeSeries() => (null, true),
    ChangeOccurrence(:final occurrence) => (occurrence, true),
    CheckTask(:final date) => (date, true),
    AddItem() || DeleteOccurrence() || DeleteItem() => (null, false),
  };
  final kind = edit.key.kind;
  if (!mustBeThere || kind == null) return null;
  final what = switch (_there(calendar, edit.key)) {
    null => GoneMeanwhile.item,
    final item when date != null =>
      hasOccurrenceAt(item, date) ? null : GoneMeanwhile.date,
    _ => null,
  };
  return what == null ? null : (kind: kind, what: what);
}

/// The item [key] if it is in [calendar], not deleted or cancelled.
CalendarItem? _there(Calendar calendar, UidKey key) =>
    switch (calendar.itemOf(key)) {
      final item? when !item.series.cancelled => item,
      _ => null,
    };
