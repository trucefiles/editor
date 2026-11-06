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
