import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'device_settings_controller.dart';

/// The view calendars open in, kept in this device's settings: the page
/// of a calendar and the Calendar tab both open in the view picked last.
final calendarViewChoiceProvider = Provider<CalendarViewChoice>(
  (ref) => CalendarViewChoice(
    last: () => ref.read(deviceSettingsProvider).requireValue.calendarView,
    keep: (kind) => ref
        .read(deviceSettingsProvider.notifier)
        .change((settings) => settings.copyWith(calendarView: kind)),
  ),
);
