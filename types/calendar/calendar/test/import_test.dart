import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'samples.dart';

/// A small invite file, as another app or an assistant writes it: a
/// lecture with its zone's block, a concert in a zone with no block, an
/// event without `UID`, a deleted event's marker, a task and a name.
const _invites = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Example//Invites//EN
X-WR-CALNAME:Invites
BEGIN:VTIMEZONE
TZID:America/Chicago
BEGIN:STANDARD
DTSTART:19701101T020000
TZOFFSETFROM:-0500
TZOFFSETTO:-0600
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
UID:lecture@example.org
DTSTAMP:20270201T090000Z
DTSTART;TZID=America/Chicago:20270304T140000
DTEND;TZID=America/Chicago:20270304T153000
SUMMARY:Lecture on tides
END:VEVENT
BEGIN:VEVENT
UID:concert@example.org
DTSTAMP:20270201T090000Z
DTSTART;TZID=Asia/Tokyo:20270320T190000
DTEND;TZID=Asia/Tokyo:20270320T213000
SUMMARY:Concert
LOCATION:Hall B
END:VEVENT
BEGIN:VEVENT
DTSTAMP:20270201T090000Z
DTSTART;VALUE=DATE:20270410
SUMMARY:Book club
END:VEVENT
BEGIN:VEVENT
UID:gone@example.org
DTSTAMP:20270201T090000Z
STATUS:CANCELLED
X-TRUCE-DELETED:TRUE
SUMMARY:Gone
END:VEVENT
BEGIN:VTODO
UID:todo@example.org
SUMMARY:Buy tickets
END:VTODO
END:VCALENDAR
''';

/// [birthday]'s event as a file holds it, last changed at [modified],
/// named [summary].
String _ann(String modified, String summary) =>
    '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:ann@truce
DTSTAMP:$modified
LAST-MODIFIED:$modified
SEQUENCE:0
DTSTART;VALUE=DATE:20200312
DTEND;VALUE=DATE:20200313
RRULE:FREQ=YEARLY
SUMMARY:$summary
END:VEVENT
END:VCALENDAR
''';

Uint8List _bytes(String text) => utf8.encode(text);

CalendarImport _import(String into, String file) =>
    importInto(Calendar.read(into)!, _bytes(file));

EventsImported _report(CalendarImport import) =>
    import.report as EventsImported;

void main() {
  test('adds the events, each as the file has it', () {
    final import = _import(birthday, _invites);
    final calendar = import.calendar;
    final file = Calendar.read(_invites)!;
    for (final uid in ['lecture@example.org', 'concert@example.org']) {
      final key = UidKey.event(uid);
      expect(calendar.unitOf(key)!.text, file.unitOf(key)!.text);
    }
    final bookClub = calendar.events.singleWhere(
      (event) => event.series.summary == 'Book club',
    );
    expect(bookClub.uid, endsWith('@truce'));
    expect(calendar.eventOf('ann@truce'), isNotNull);
    final report = _report(import);
    expect((report.added, report.updated), (3, 0));
    expect(report.kept, isEmpty);
  });

  test('leaves out markers, other components and the name', () {
    final calendar = _import(birthday, _invites).calendar;
    expect(calendar.eventOf('gone@example.org'), isNull);
    expect(calendar.unitOf(const UidKey('VTODO', 'todo@example.org')), isNull);
    expect(calendar.name, 'Birthdays');
  });

  test("takes the file's zone block, else makes one", () {
    final import = _import(birthday, _invites);
    final file = Calendar.read(_invites)!;
    const chicago = ZoneKey('America/Chicago');
    expect(import.calendar.unitOf(chicago)!.text, file.unitOf(chicago)!.text);
    expect(import.calendar.zones, {'America/Chicago', 'Asia/Tokyo'});
    expect(import.written, contains(const ZoneKey('Asia/Tokyo')));
  });

  test("keeps the calendar's own zone block", () {
    final first = _import(birthday, _invites).calendar;
    const tokyo = ZoneKey('Asia/Tokyo');
    final own = first.unitOf(tokyo)!.text;
    final again = importInto(
      first.withUnitsChanged({const UidKey.event('concert@example.org'): null}),
      _bytes(_invites),
    );
    expect(again.calendar.unitOf(tokyo)!.text, own);
    expect(again.written, [const UidKey.event('concert@example.org')]);
  });

  test('importing the same file again changes nothing', () {
    final first = _import(birthday, _invites).calendar;
    final again = importInto(first, _bytes(_invites));
    expect(again.written, isEmpty);
    expect(again.calendar.text, first.text);
    final report = _report(again);
    expect((report.added, report.updated), (0, 0));
    expect(report.kept, isEmpty);
  });

  test("a newer version updates the event, an older one doesn't", () {
    final newer = _import(birthday, _ann('20261101T080000Z', 'Ann (50)'));
    expect(newer.calendar.eventOf('ann@truce')!.series.summary, 'Ann (50)');
    expect((_report(newer).added, _report(newer).updated), (0, 1));

    final older = _import(birthday, _ann('20250101T080000Z', 'Anne'));
    expect(older.written, isEmpty);
    expect(older.calendar.eventOf('ann@truce')!.series.summary, 'Ann');
    expect(_report(older).kept, ['Ann']);
  });

  test('a file that is no calendar changes nothing', () {
    final calendar = Calendar.read(birthday)!;
    for (final bytes in [
      Uint8List.fromList([0xC3, 0x28]),
      _bytes('Just a note.\n'),
    ]) {
      final import = importInto(calendar, bytes);
      expect(import.report, isA<NotACalendar>());
      expect(import.written, isEmpty);
      expect(import.calendar, same(calendar));
    }
  });

  test('a calendar without events changes nothing', () {
    final import = _import(birthday, '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VTODO
UID:todo@example.org
SUMMARY:Buy tickets
END:VTODO
END:VCALENDAR
''');
    expect(import.report, isA<NoEvents>());
    expect(import.written, isEmpty);
  });
}
