import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'device_settings_controller.dart';
import 'followed_setting.dart';

/// The view calendars open in, kept in this device's settings: the page
/// of a calendar and the Calendar tab both open in the view picked last.
final calendarViewChoiceProvider = Provider<CalendarViewChoice>((ref) {
  final settings = ref.read(deviceSettingsProvider.notifier);
  return CalendarViewChoice(
    last: followedSetting(ref, (s) => s.calendarView),
    keep: (kind) =>
        settings.change((settings) => settings.copyWith(calendarView: kind)),
  );
});
