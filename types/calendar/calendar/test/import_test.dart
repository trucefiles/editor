import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart' show MergedText;

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

/// When the tests import.
final _at = DateTime.utc(2027, 2, 10, 12);

CalendarImport _import(String into, String file) =>
    importInto(Calendar.read(into)!, _bytes(file), _at);

EventsImported _report(CalendarImport import) =>
    import.report as EventsImported;

/// [unit]'s lines but its edit stamps.
List<String> _content(CalendarUnit unit) => [
  for (final line in unit.text.split('\n'))
    if (!RegExp('^(DTSTAMP|LAST-MODIFIED|SEQUENCE)[:;]').hasMatch(line)) line,
];

void main() {
  test('adds the events as the file has them, stamped as an edit now', () {
    final import = _import(birthday, _invites);
    final calendar = import.calendar;
    final file = Calendar.read(_invites)!;
    for (final uid in ['lecture@example.org', 'concert@example.org']) {
      final key = UidKey.event(uid);
      expect(_content(calendar.unitOf(key)!), _content(file.unitOf(key)!));
      final event = calendar.eventOf(uid)!.series.component;
      expect(event.value('LAST-MODIFIED'), '20270210T120000Z');
    }
    final bookClub = calendar.events.singleWhere(
      (event) => event.series.summary == 'Book club',
    );
    expect(bookClub.uid, endsWith('@truce'));
    expect(calendar.eventOf('ann@truce'), isNotNull);
    final report = _report(import);
    expect((report.added, report.updated), (3, 0));
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
      _at,
    );
    expect(again.calendar.unitOf(tokyo)!.text, own);
    expect(again.written, [const UidKey.event('concert@example.org')]);
  });

  test('importing the same file again changes nothing', () {
    final first = _import(birthday, _invites).calendar;
    final again = importInto(first, _bytes(_invites), _at.add(_day));
    expect(again.written, isEmpty);
    expect(again.calendar.text, first.text);
    final report = _report(again);
    expect((report.added, report.updated), (0, 0));
  });

  test("the file's version wins, newer or older, and wins a later merge", () {
    for (final modified in ['20261101T080000Z', '20250101T080000Z']) {
      final import = _import(birthday, _ann(modified, 'Ann (50)'));
      final ann = import.calendar.eventOf('ann@truce')!.series;
      expect(ann.summary, 'Ann (50)');
      expect(ann.component.value('SEQUENCE'), '1', reason: 'above both');
      expect((_report(import).added, _report(import).updated), (0, 1));
      final merged = const CalendarMerge().merge(
        birthday,
        import.calendar.text,
      );
      expect((merged as MergedText).text, import.calendar.text);
    }
  });

  test('an event deleted here comes back', () {
    final concert = DeleteEvent('concert@example.org', at: _at.add(_day));
    final deleted = applyEdit(_import(birthday, _invites).calendar, concert);
    final again = importInto(deleted, _bytes(_invites), _at.add(_day * 2));
    final back = again.calendar.eventOf('concert@example.org')!.series;
    expect((back.deleted, back.summary), (false, 'Concert'));
    expect((_report(again).added, _report(again).updated), (1, 0));
  });

  test('a file of one changed date keeps the series and its other dates', () {
    const series = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:choir@example.org
DTSTAMP:20270101T090000Z
DTSTART:20270104T190000
DTEND:20270104T210000
RRULE:FREQ=WEEKLY
SUMMARY:Choir
END:VEVENT
BEGIN:VEVENT
UID:choir@example.org
RECURRENCE-ID:20270111T190000
DTSTAMP:20270101T090000Z
DTSTART:20270111T200000
DTEND:20270111T220000
SUMMARY:Choir (late)
END:VEVENT
END:VCALENDAR
''';
    const moved = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:choir@example.org
RECURRENCE-ID:20270118T190000
DTSTAMP:20270105T090000Z
DTSTART:20270119T190000
DTEND:20270119T210000
SUMMARY:Choir (Tuesday)
END:VEVENT
END:VCALENDAR
''';
    final import = _import(series, moved);
    final choir = import.calendar.eventOf('choir@example.org')!;
    expect(choir.series.summary, 'Choir');
    expect(choir.series.repeat, isNotNull);
    expect(choir.changed.map((part) => part.summary), [
      'Choir (late)',
      'Choir (Tuesday)',
    ]);
    expect((_report(import).added, _report(import).updated), (0, 1));

    final again = importInto(import.calendar, _bytes(moved), _at.add(_day));
    expect(again.written, isEmpty, reason: 'that date is there already');
  });

  test('two invites for single dates of one series add up', () {
    String invite(String day) =>
        '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:tennis@example.org
RECURRENCE-ID:202703${day}T180000
DTSTAMP:20270301T090000Z
DTSTART:202703${day}T183000
DTEND:202703${day}T193000
SUMMARY:Tennis $day
END:VEVENT
END:VCALENDAR
''';
    final first = _import(birthday, invite('02')).calendar;
    final both = importInto(first, _bytes(invite('09')), _at.add(_day));
    final tennis = both.calendar.eventOf('tennis@example.org')!;
    expect([tennis.series, ...tennis.changed].map((part) => part.summary), [
      'Tennis 02',
      'Tennis 09',
    ]);
    expect(_report(both).updated, 1);
  });

  test('a changed date that is unreadable leaves the series as it is', () {
    final import = _import(birthday, '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:ann@truce
RECURRENCE-ID;VALUE=DATE:2021-03-12
DTSTAMP:20270201T090000Z
DTSTART;VALUE=DATE:20210313
SUMMARY:Moved
END:VEVENT
END:VCALENDAR
''');
    expect(import.written, isEmpty);
    expect(import.calendar.text, birthday);
    final ann = import.calendar.eventOf('ann@truce')!;
    expect(ann.series.summary, 'Ann');
    expect(ann.series.repeat, isNotNull);
  });

  test('events with a blank UID are each their own, given a UID', () {
    final import = _import(birthday, '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:
DTSTART;VALUE=DATE:20270410
SUMMARY:Book club
END:VEVENT
BEGIN:VEVENT
UID: 
DTSTART;VALUE=DATE:20270417
SUMMARY:Choir
END:VEVENT
END:VCALENDAR
''');
    expect(_report(import).added, 2);
    final added = import.calendar.events.where((e) => e.uid != 'ann@truce');
    expect(added.map((e) => e.series.summary), ['Book club', 'Choir']);
    expect(added.map((e) => e.uid), everyElement(endsWith('@truce')));
  });

  test('one event without UID twice in a file is added once', () {
    const bookClub = '''BEGIN:VEVENT
DTSTAMP:20270201T090000Z
DTSTART;VALUE=DATE:20270410
SUMMARY:Book club
END:VEVENT
''';
    final import = _import(
      birthday,
      'BEGIN:VCALENDAR\nVERSION:2.0\n$bookClub${bookClub}END:VCALENDAR\n',
    );
    expect(_report(import).added, 1);
    expect(
      import.calendar.events.where((e) => e.series.summary == 'Book club'),
      hasLength(1),
    );
  });

  test('an event without UID exported again later is the same event', () {
    final first = _import(birthday, _invites).calendar;
    final exportedLater = _invites.replaceAll(
      'DTSTAMP:20270201T090000Z',
      'DTSTAMP:20270301T090000Z',
    );
    final again = importInto(first, _bytes(exportedLater), _at.add(_day));
    expect(
      again.calendar.events.where((e) => e.series.summary == 'Book club'),
      hasLength(1),
    );
  });

  test('a file that is no calendar changes nothing', () {
    final calendar = Calendar.read(birthday)!;
    for (final bytes in [
      Uint8List.fromList([0xC3, 0x28]),
      _bytes('Just a note.\n'),
    ]) {
      final import = importInto(calendar, bytes, _at);
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

const _day = Duration(days: 1);
