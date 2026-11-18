import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

/// The time now, for the calendars; a fixed clock in tests.
final calendarNowProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// The calendars' one clock, for the app's whole run: the views and the
/// alerts move on with it.
final calendarClockProvider = Provider<CalendarClock>((ref) {
  final clock = CalendarClock(ref.watch(calendarNowProvider));
  ref.onDispose(clock.dispose);
  return clock;
});
