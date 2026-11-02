import 'dart:async';

import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_documents/truce_documents.dart';

import 'calendar_tab_controller.dart';

/// What the Calendar tab keeps while the app runs: [today], and the
/// calendar the user added to last ([lastUsed]), offered first.
typedef TabPicks = ({DateTime today, DocumentKey? lastUsed});

/// The time now, for the Calendar tab's today; a fixed clock in tests.
final calendarClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

final calendarTabPicksProvider = NotifierProvider<CalendarTabPicks, TabPicks>(
  CalendarTabPicks.new,
);

/// What the Calendar tab keeps: today moves on at each midnight, and the
/// calendar added to last.
class CalendarTabPicks extends Notifier<TabPicks> {
  Timer? _midnight;

  @override
  TabPicks build() {
    ref.onDispose(() => _midnight?.cancel());
    return (today: _today(), lastUsed: null);
  }

  /// Today, and a wake at the next midnight to move it on.
  DateTime _today() {
    final now = ref.read(calendarClockProvider)();
    final today = DateUtils.dateOnly(now);
    _midnight?.cancel();
    _midnight = Timer(
      DateTime(today.year, today.month, today.day + 1).difference(now),
      () => state = (today: _today(), lastUsed: state.lastUsed),
    );
    return today;
  }

  /// The user adds to [calendar]: offered first next time, whatever
  /// version it has then.
  void addTo(Document calendar) =>
      state = (today: state.today, lastUsed: calendar.key);
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
