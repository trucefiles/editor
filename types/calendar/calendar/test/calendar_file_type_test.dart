import 'dart:convert';

import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

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
  CalendarFileType calendars() => CalendarFileType(
    eventLine: (occurrence) =>
        '${occurrence.start.month}/${occurrence.start.day} '
        '${occurrence.part.summary}',
    cycleLine: (cycle, today) => 'day ${cycle.dayOfCycle(today)}',
    now: () => DateTime(2026, 11),
  );
  final read = FileText(
    ListedFile(
      folder: Folder(
        id: folderId('home'),
        name: 'Home',
        color: 'teal',
        location: 'home',
      ),
      path: path('birthdays.ics'),
      type: const CalendarSupport(),
      version: const FileVersion(0),
      modified: DateTime(2000),
    ),
    const TextFile.empty().withText(_birthday),
  );

  test('a new calendar starts empty, with no name', () {
    final type = calendars();
    final [plain, health] = type.newKinds;
    expect([plain.label, health.label], ['Calendar', 'Health calendar']);
    for (final (kind, isHealth) in [(plain, false), (health, true)]) {
      final calendar = Calendar.read(kind.start)!;
      expect((calendar.name, calendar.isHealth), ('', isHealth));
      expect(calendar.units, isEmpty);
      expect(kind.start, isNot(contains('X-WR-CALNAME')));
    }
    expect(utf8.decode(type.newFile.encode('a\nb')), 'a\r\nb');
    expect(type.newFileExtension, '.ics');
  });

  test('a card shows the name and the next events, until the first ends', () {
    final card = calendars().cardSummary(read);

    expect(card.title, 'Birthdays');
    expect(card.preview(ViewSettings.none), '3/12 Ann');
    expect(card.holdsUntil, DateTime(2027, 3, 13));
  });

  test('search finds the name, titles and notes, not the file words', () {
    expect(calendars().searchText(read), 'Birthdays\nAnn\nBring cake');
  });
}
