import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_documents/truce_documents.dart';

import 'calendar_tab_controller.dart';

/// The time now, for the Calendar tab's views; a fixed clock in tests.
final calendarClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

final lastUsedCalendarProvider =
    NotifierProvider<LastUsedCalendar, DocumentKey?>(LastUsedCalendar.new);

/// The calendar the user added to last in the Calendar tab, offered
/// first next time, whatever version it has then; kept while the app
/// runs.
class LastUsedCalendar extends Notifier<DocumentKey?> {
  @override
  DocumentKey? build() => null;

  /// The user adds to [calendar].
  void addTo(Document calendar) => state = calendar.key;
}

/// [calendars] to add to, the one used last ([lastUsed]) first.
List<TabCalendar> forAdding(
  List<TabCalendar> calendars,
  DocumentKey? lastUsed,
) => [
  ...calendars.where((each) => each.document.key == lastUsed),
  ...calendars.where((each) => each.document.key != lastUsed),
];

/// What [calendar] is called: its own name, else its file's.
String tabCalendarName(TabCalendar calendar) =>
    switch (calendar.calendar.name.trim()) {
      '' => nameTitle(calendar.document.path),
      final name => name,
    };
