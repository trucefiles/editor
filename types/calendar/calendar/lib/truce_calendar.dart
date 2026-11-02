/// Calendar files for Truce: one iCalendar file (`.ics`) per calendar,
/// read into units (an event with its changed occurrences), edited unit
/// by unit and printed back block-exact (untouched units keep their
/// bytes); merged unit by unit, the one changed or the newer edit winning
/// ([CalendarMerge]);
/// repeats expanded into occurrences ([occurrences]); health entries as
/// tagged all-day events, with cycle predictions derived, never stored
/// ([predictCycle]).
///
/// Also the type as the app shows it ([CalendarFileType]) and what a
/// calendar keeps of how it shows ([CalendarView], [CalendarViewKind]).
///
/// Pure Dart, no UI; `core` and `files` know nothing of it. What the app
/// uses is exported here.
library;

export 'src/edit/calendar_edit.dart';
export 'src/edit/device_zone.dart';
export 'src/edit/event_draft.dart';
export 'src/edit/new_uid.dart';
export 'src/edit/occurrence_edits.dart';
export 'src/health/cycle.dart';
export 'src/merge/calendar_merge.dart';
export 'src/model/calendar.dart';
export 'src/model/calendar_event.dart' show CalendarEvent, EventPart;
export 'src/model/calendar_time.dart';
export 'src/model/calendar_unit.dart';
export 'src/model/health_entry.dart';
export 'src/model/repeat.dart';
export 'src/owner/calendar_owner.dart';
export 'src/recurrence/occurrences.dart';
export 'src/support/calendar_file_type.dart';
export 'src/support/calendar_summary.dart';
export 'src/support/calendar_support.dart';
export 'src/views/calendar_view.dart';
export 'src/views/calendar_view_choice.dart';
export 'src/views/calendar_view_kind.dart';
