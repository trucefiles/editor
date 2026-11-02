import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import 'calendar_tab_controller.dart';

/// The time now, for the Calendar tab's views; a fixed clock in tests.
final calendarClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

final lastUsedCalendarProvider = NotifierProvider<LastUsedCalendar, FileKey?>(
  LastUsedCalendar.new,
);

/// The calendar the user added to last in the Calendar tab, offered
/// first next time, whatever version it has then; kept while the app
/// runs.
class LastUsedCalendar extends Notifier<FileKey?> {
  @override
  FileKey? build() => null;

  /// The user adds to [calendar].
  void addTo(ListedFile calendar) => state = calendar.key;
}

/// [calendars] to add to, the one used last ([lastUsed]) first.
List<TabCalendar> forAdding(List<TabCalendar> calendars, FileKey? lastUsed) => [
  ...calendars.where((each) => each.file.key == lastUsed),
  ...calendars.where((each) => each.file.key != lastUsed),
];

/// What [calendar] is called: its own name, else its file's.
String tabCalendarName(TabCalendar calendar) =>
    switch (calendar.calendar.name.trim()) {
      '' => nameTitle(calendar.file.path),
      final name => name,
    };
