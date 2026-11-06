import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end test of a new calendar in the real app on the desktop,
/// against a real folder: made, given an event, written, opened again and
/// shown in the Calendar tab, whose event opens the calendar again.
///
/// Run on Linux with `flutter test integration_test/calendar_test.dart -d
/// linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  testApp('a new calendar is named in its title, written with its first '
      'event, and shows in the Calendar tab', (tester) async {
    await tester.addFolder(app);

    await tester.tapAndSettle(find.byTooltip('New file'));
    await tester.tapAndSettle(find.widgetWithText(ListTile, 'Calendar'));
    await tester.enterText(_nameField, 'Family');
    await tester.pump();
    await tester.tapAndSettle(find.byTooltip('Add event'));
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Dentist');
    await tester.tapAndSettle(find.text('Save'));
    expect(find.text('Dentist'), findsOneWidget);
    await tester.pageBack();
    await tester.waitForNoteClosed();

    final file = app.file('Family.ics');
    await tester.waitUntil(file.existsSync);
    final text = file.readAsStringSync();
    expect(text, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(text, contains('X-WR-CALNAME:Family\r\n'));
    expect(text, contains('SUMMARY:Dentist\r\n'));
    expect(text.replaceAll('\r\n', ''), isNot(contains('\n')));

    await tester.openFile('Family');
    expect(find.text('Dentist'), findsOneWidget);
    await tester.pageBack();
    await tester.waitForNoteClosed();

    await tester.tapAndSettle(
      find.widgetWithText(NavigationDestination, 'Calendars'),
    );
    await tester.waitFor(find.widgetWithText(FilterChip, 'Family'));
    expect(find.text('Dentist'), findsOneWidget);

    // An event in the tab shows; Open calendar opens its page.
    await tester.tapAndSettle(find.text('Dentist'));
    await tester.tapAndSettle(find.text('Open calendar'));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);
  });

  testApp('events imported from a file are merged in and written', (
    tester,
  ) async {
    app
      ..write('Garden.ics', _garden)
      ..calendarToImport = utf8.encode(_seeds);
    await tester.addFolder(app);
    await tester.openFile('Garden');

    await tester.chooseInMenu('Import events…');
    expect(find.text('Seed swap'), findsOneWidget);
    expect(find.text('Added 1 event.'), findsOneWidget);
    await tester.pageBack();
    await tester.waitForNoteClosed();

    final file = app.file('Garden.ics');
    await tester.waitUntil(
      () => file.readAsStringSync().contains('SUMMARY:Seed swap\r\n'),
    );
    expect(file.readAsStringSync(), contains('SUMMARY:Pruning\r\n'));
  });

  testApp('a new calendar left with no name and no event is not written', (
    tester,
  ) async {
    await tester.addFolder(app);

    await tester.tapAndSettle(find.byTooltip('New file'));
    await tester.tapAndSettle(find.widgetWithText(ListTile, 'Calendar'));
    await tester.enterText(_nameField, 'Trip');
    await tester.pump();
    await tester.enterText(_nameField, '');
    await tester.pump();
    await tester.pageBack();
    await tester.waitForNoteClosed();

    expect(app.topFiles, isEmpty);
  });

  testApp('a new calendar with an event and no name is named after its '
      'kind', (tester) async {
    await tester.addFolder(app);

    await tester.tapAndSettle(find.byTooltip('New file'));
    await tester.tapAndSettle(find.widgetWithText(ListTile, 'Calendar'));
    await tester.tapAndSettle(find.byTooltip('Add event'));
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Dentist');
    await tester.tapAndSettle(find.text('Save'));
    await tester.pageBack();
    await tester.waitForNoteClosed();

    final file = app.file('Calendar.ics');
    await tester.waitUntil(file.existsSync);
    expect(file.readAsStringSync(), isNot(contains('X-WR-CALNAME')));
  });
}

/// The calendar's name, edited in the page's title.
final _nameField = find.descendant(
  of: find.byType(AppBar),
  matching: find.byType(TextField),
);

/// A calendar file with one event this month.
final _garden = [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//Example//Garden//EN',
  'X-WR-CALNAME:Garden',
  'BEGIN:VEVENT',
  'UID:pruning@example.org',
  'DTSTAMP:20260101T090000Z',
  'DTSTART;VALUE=DATE:${_day(3)}',
  'DTEND;VALUE=DATE:${_day(4)}',
  'SUMMARY:Pruning',
  'END:VEVENT',
  'END:VCALENDAR',
  '',
].join('\r\n');

/// A file to import, of one event this month.
final _seeds = [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'BEGIN:VEVENT',
  'UID:seeds@example.org',
  'DTSTAMP:20260101T090000Z',
  'DTSTART;VALUE=DATE:${_day(20)}',
  'DTEND;VALUE=DATE:${_day(21)}',
  'SUMMARY:Seed swap',
  'END:VEVENT',
  'END:VCALENDAR',
  '',
].join('\r\n');

/// Day [day] of this month, as a calendar file writes a date.
String _day(int day) {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(day)}';
}
