import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor/common/time_texts.dart';
import 'package:truce_editor/file_types/file_types.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_files/truce_files.dart';

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
END:VEVENT
END:VCALENDAR
''';

void main() {
  setUpAll(initializeDateFormatting);

  test('the app handles Markdown, plain text and calendars', () {
    final types = appFileTypes();
    expect(types.of(path('a.md')), isA<MarkdownEditableType>());
    expect(types.of(path('a.txt')), isA<PlainTextEditableType>());
    expect(types.of(path('a.ics')), isA<CalendarEditableType>());
    expect(types.of(path('a.pdf')), isNull);
  });

  test('a plain new file is a note; calendars are made named', () {
    final types = appFileTypes();
    expect(
      [for (final made in types.newFileChoices) made.label],
      ['Note', 'Calendar', 'Health calendar'],
    );
    expect(types.forNew, isA<MarkdownEditableType>());
  });

  test('new events take the zone the platform tells', () {
    Future<String?> zone() async => 'Europe/Berlin';
    final container = ProviderContainer(
      overrides: [deviceZoneProvider.overrideWithValue(zone)],
    );
    addTearDown(container.dispose);
    final types = container.read(fileTypesProvider);
    expect(
      (types.of(path('a.ics'))! as CalendarEditableType).deviceZone,
      same(zone),
    );
  });

  test("calendar cards write days in the app's time texts", () {
    final type = CalendarEditableType(
      day: TimeTexts(locale: 'en', use24Hour: true).day,
      deviceZone: () async => null,
      viewChoice: CalendarViewChoice(
        last: () => CalendarViewKind.month,
        keep: (_) async {},
      ),
      now: () => DateTime(2026, 11),
    );
    final card = type.cardSummary(
      fileTextOf(folderAt(tempFolder()), _birthday, name: 'birthdays.ics'),
    );

    expect(card.preview(ViewSettings.none), 'Fri, Mar 12  Ann');
  });
}
