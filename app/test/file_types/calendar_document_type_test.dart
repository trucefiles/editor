import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_editor/common/time_texts.dart';
import 'package:truce_editor/file_types/calendar_document_type.dart';
import 'package:truce_editor/file_types/document_types.dart';
import 'package:truce_editor/platform/platform_wiring.dart';

import '../support.dart';

const _birthday = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Truce Editor//Calendar//EN
X-WR-CALNAME:Birthdays
BEGIN:VEVENT
UID:ann@truce
DTSTAMP:20261001T080000Z
DTSTART;VALUE=DATE:20200312
DTEND;VALUE=DATE:20200313
RRULE:FREQ=YEARLY
SUMMARY:Ann
DESCRIPTION:Bring cake
END:VEVENT
END:VCALENDAR
''';

void main() {
  setUpAll(initializeDateFormatting);

  final folder = folderAt(Directory('/documents'));
  CalendarDocumentType calendars() => CalendarDocumentType(
    times: TimeTexts(locale: 'en', use24Hour: true),
    deviceZone: () async => null,
    now: () => DateTime(2026, 11),
  );
  final read = documentTextOf(folder, _birthday, name: 'birthdays.ics');

  test('the app handles .ics files as calendars', () {
    final types = appDocumentTypes();
    expect(types.of(path('a.ics')), isA<CalendarDocumentType>());
    expect([
      for (final made in types.newDocuments) made.label,
    ], containsAllInOrder(['Calendar', 'Health calendar']));
    expect(types.forNew, isNot(isA<CalendarDocumentType>()));
  });

  test('new events take the zone the platform tells', () {
    Future<String?> zone() async => 'Europe/Berlin';
    final container = ProviderContainer(
      overrides: [deviceZoneProvider.overrideWithValue(zone)],
    );
    addTearDown(container.dispose);
    final types = container.read(documentTypesProvider);
    expect(
      (types.of(path('a.ics'))! as CalendarDocumentType).deviceZone,
      same(zone),
    );
  });

  test('a new calendar starts as its named, empty calendar', () {
    final type = calendars();
    final [plain, health] = type.newDocuments;
    expect(Calendar.read(plain.startText('Home'))!.name, 'Home');
    expect(Calendar.read(plain.startText('Home'))!.isHealth, isFalse);
    expect(Calendar.read(health.startText('Me'))!.isHealth, isTrue);
    expect(utf8.decode(type.newFile.encode('a\nb')), 'a\r\nb');
  });

  test('a card shows the name and the next events, until the first ends', () {
    final card = calendars().cardSummary(read);

    expect(card.title, 'Birthdays');
    expect(card.preview(ViewSettings.none), 'Fri, Mar 12  Ann');
    expect(card.holdsUntil, DateTime(2027, 3, 13));
  });

  test('search finds the name, titles and notes, not the file words', () {
    expect(calendars().searchText(read), 'Birthdays\nAnn\nBring cake');
  });
}
