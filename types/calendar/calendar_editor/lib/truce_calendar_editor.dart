/// The calendar page of a calendar file: its events in month, week,
/// day and schedule views (on the `kalender` package), the event form,
/// and for a health calendar its entry kinds with their own forms, its
/// cycle shaded and told above; the same views for the Calendar tab; the calendar type as the file page opens it
/// ([CalendarEditableType]). Flutter widgets only; what a calendar is
/// lives in `calendar`.
library;

export 'src/calendar_editable_type.dart';
export 'src/calendar_editor_part.dart';
export 'src/calendar_editor_view.dart';
export 'src/calendar_start.dart';
export 'src/ui/occurrence_details.dart';
export 'src/ui/occurrence_texts.dart' show DayText;
export 'src/views/calendar_views.dart' show CalendarViews;
