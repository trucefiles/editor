import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/ui/event_form.dart';
import 'package:truce_calendar_editor/src/ui/task_form.dart';

/// What the alert field says below it, now that alerts ring.
const _rings = 'Rings for the calendars shown in the Calendars tab';

void main() {
  Future<void> pump(WidgetTester tester, Widget form) =>
      tester.pumpWidget(MaterialApp(home: form));

  testWidgets("the event form's alert says which calendars ring", (
    tester,
  ) async {
    final day = DateTime.utc(2026, 11, 3);
    await pump(
      tester,
      EventForm(
        EventDraft(summary: 'Dentist', start: AllDay(day), end: AllDay(day)),
        title: 'Edit event',
        deviceZone: null,
      ),
    );

    expect(find.text(_rings), findsOne);
    expect(find.textContaining("doesn't remind you"), findsNothing);
  });

  testWidgets("the task form's alert says which calendars ring", (
    tester,
  ) async {
    final day = DateTime(2026, 11, 3);
    await pump(
      tester,
      TaskForm(
        TaskDraft(summary: 'Pay rent', due: AllDay(day)),
        title: 'Edit task',
        deviceZone: null,
        today: day,
      ),
    );

    expect(find.text(_rings), findsOne);
    expect(find.textContaining("doesn't remind you"), findsNothing);
  });
}
