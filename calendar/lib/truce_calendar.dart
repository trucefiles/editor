/// Calendar documents for Truce: one iCalendar file (`.ics`) per calendar,
/// read into units (an event with its changed occurrences), edited unit
/// by unit and printed back block-exact (untouched units keep their
/// bytes); merged unit by unit, the newer edit winning ([CalendarMerge]);
/// repeats expanded into occurrences ([occurrences]); health entries as
/// tagged all-day events, with cycle predictions derived, never stored
/// ([predictCycle]).
///
/// Pure Dart, no UI; `core` knows nothing of it. What the app uses is
/// exported here.
library;

export 'src/edit/calendar_edit.dart';
export 'src/edit/event_draft.dart';
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
export 'src/support/calendar_summary.dart';
export 'src/support/calendar_support.dart';
