import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

import '../platform/calendar_file_picker.dart';
import '../platform/link_opener.dart';
import '../platform/place_opener.dart';

/// What calendar pages are asked to start with (e.g. by the Calendar
/// tab's Edit), one for the whole app: handed to the calendar type and
/// to the tab.
final calendarStartsProvider = Provider<CalendarStarts>(
  (ref) => CalendarStarts(),
);

/// Asks the user for a calendar file to import into an open calendar.
final calendarFilePickerProvider = Provider<PickCalendarFile>(
  (ref) => pickCalendarFile,
);

/// How calendars open the links and places their events name: links as
/// documents' do, places in a maps app.
final eventOpenersProvider = Provider<EventOpeners>(
  (ref) => EventOpeners(
    openLink: ref.watch(linkOpenerProvider).open,
    openPlace: ref.watch(placeOpenerProvider).open,
  ),
);
