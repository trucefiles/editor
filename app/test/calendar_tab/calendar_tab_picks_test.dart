import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_editor/calendar_tab/calendar_tab_controller.dart';
import 'package:truce_editor/calendar_tab/calendar_tab_picks.dart';

import '../support.dart';

void main() {
  final folder = folderAt(Directory('/documents'));

  /// A calendar named [name] with one [event] on [day] from 9 to 10.
  TabCalendar calendar(
    String name,
    String event,
    DateTime day, {
    bool shown = true,
  }) => (
    file: listedFile(folder, name: '${name.toLowerCase()}.ics'),
    calendar: applyEdit(
      Calendar.read(newCalendarText(name))!,
      AddEvent(
        event,
        EventDraft(
          summary: event,
          start: Floating(DateTime.utc(day.year, day.month, day.day, 9)),
          end: Floating(DateTime.utc(day.year, day.month, day.day, 10)),
        ),
        at: DateTime.utc(2026, 11),
      ),
    ),
    shown: shown,
  );

  final home = calendar('Home', 'Dentist', DateTime(2026, 11, 5));
  final work = calendar('Work', 'Review', DateTime(2026, 11, 5));

  test('the calendar added to last is offered first', () {
    expect(
      [
        for (final each in forAdding([home, work], work.file.key))
          tabCalendarName(each),
      ],
      ['Work', 'Home'],
    );
  });

  test('the calendar added to stays first once it changed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(lastUsedCalendarProvider.notifier).addTo(work.file);
    final changed = (
      file: listedFile(folder, name: 'work.ics', version: 1),
      calendar: work.calendar,
      shown: true,
    );

    final first = forAdding([
      home,
      changed,
    ], container.read(lastUsedCalendarProvider)).first;
    expect(tabCalendarName(first), 'Work');
  });
}
