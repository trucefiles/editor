import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../settings/device_settings_controller.dart';
import '../settings/followed_setting.dart';

/// The view the Calendar tab opens in, kept in this device's settings:
/// the one picked last there. Each calendar's page keeps its own.
final tabViewChoiceProvider = Provider<CalendarViewChoice>((ref) {
  final settings = ref.read(deviceSettingsProvider.notifier);
  final last = followedSetting(ref, (s) => s.tabCalendarView);
  return CalendarViewChoice(
    last: () => last.value,
    keep: (kind) =>
        settings.change((settings) => settings.copyWith(tabCalendarView: kind)),
  );
});
