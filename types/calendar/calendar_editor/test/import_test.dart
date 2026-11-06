import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/ui/import_texts.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'page_harness.dart';

/// A file of two events, as another app writes it.
const _picnics = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:picnic@example.org
DTSTAMP:20270501T090000Z
DTSTART;VALUE=DATE:20270515
DTEND;VALUE=DATE:20270516
SUMMARY:Picnic
END:VEVENT
BEGIN:VEVENT
UID:kites@example.org
DTSTAMP:20270501T090000Z
DTSTART;VALUE=DATE:20270522
DTEND;VALUE=DATE:20270523
SUMMARY:Kite day
END:VEVENT
END:VCALENDAR
''';

/// Picks Import events in the page's menu.
Future<void> _import(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('file menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Import events…'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('imports the picked file: one undo step, told what came', (
    tester,
  ) async {
    final part = calendarPart(
      newCalendarText('Home'),
      pickFile: () async => Ok(utf8.encode(_picnics)),
    );
    final hints = <String>[];
    await pumpPage(tester, part, today: DateTime(2027, 5, 10), hints: hints);

    await _import(tester);
    expect(calendarOf(part).events.map((event) => event.series.summary), [
      'Picnic',
      'Kite day',
    ]);
    expect(find.text('Picnic'), findsOne);
    expect(hints, ['Added 2 events.']);
    expect(part.owner.state.status.canUndo, isTrue);

    await _import(tester);
    expect(hints.last, 'These events are already in the calendar.');
  });

  testWidgets('a file that is no calendar, or not read, changes nothing', (
    tester,
  ) async {
    Result<Uint8List?, FileNotRead> pick = Ok(utf8.encode('A note.\n'));
    final part = calendarPart(
      newCalendarText('Home'),
      pickFile: () async => pick,
    );
    final hints = <String>[];
    await pumpPage(tester, part, today: DateTime(2027, 5, 10), hints: hints);

    await _import(tester);
    pick = const Err(FileNotRead());
    await _import(tester);
    pick = const Ok(null);
    await _import(tester);

    expect(hints, ["This file isn't a calendar.", "Couldn't read this file."]);
    expect(calendarOf(part).events, isEmpty);
    expect(part.owner.state.status.canUndo, isFalse);
  });

  testWidgets('no import while the calendar is only to read', (tester) async {
    final part = calendarPart(newCalendarText('Home'), readOnly: true);
    await pumpPage(tester, part, today: DateTime(2027, 5, 10));

    await tester.tap(find.byKey(const Key('file menu')));
    await tester.pumpAndSettle();
    expect(find.text('Import events…'), findsNothing);
  });

  test('tells what an import came to', () {
    String told(ImportReport report) => importHint(FileImported(report));
    expect(
      told(
        const EventsImported(added: 1, updated: 2, kept: [], deletedHere: []),
      ),
      'Added 1 event and updated 2.',
    );
    expect(
      told(
        const EventsImported(
          added: 0,
          updated: 1,
          kept: ['Swim'],
          deletedHere: [],
        ),
      ),
      'Updated 1 event. Kept your newer version of "Swim".',
    );
    expect(
      told(
        const EventsImported(
          added: 0,
          updated: 0,
          kept: ['A', 'B'],
          deletedHere: [],
        ),
      ),
      'Kept your newer versions of "A", "B".',
    );
    expect(
      told(
        const EventsImported(
          added: 1,
          updated: 0,
          kept: [],
          deletedHere: ['Dentist'],
        ),
      ),
      'Added 1 event. "Dentist" was deleted here, so it stays deleted.',
    );
    expect(told(const NoEvents()), 'There are no events in this file.');
  });
}
