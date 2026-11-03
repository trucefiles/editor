import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

/// What calendar pages are asked to start with (e.g. by the Calendar
/// tab's Edit), one for the whole app: handed to the calendar type and
/// to the tab.
final calendarStartsProvider = Provider<CalendarStarts>(
  (ref) => CalendarStarts(),
);
