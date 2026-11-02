import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';

import 'samples.dart';

final _at = DateTime.utc(2026, 11, 1, 12);

EventDraft _draft(String summary, CalendarTime start) => EventDraft(
  summary: summary,
  start: start,
  end: start.at(start.wall.add(const Duration(hours: 1))),
);

/// [text] after a new event [uid] at 9:00 on 3 November 2026 in [zone].
String _added(String text, String uid, String zone, {DateTime? at}) =>
    applyEdit(
      Calendar.read(text)!,
      AddEvent(
        uid,
        _draft('Call', Zoned(zone, DateTime(2026, 11, 3, 9))),
        at: at ?? _at,
      ),
    ).text;

/// The block a calendar gets for a new event in [zone].
String _blockOf(String zone) =>
    Calendar.read(_added(birthday, 'a', zone))!.unitOf(ZoneKey(zone))!.text;

void main() {
  group('a new event in a zone adds its block', () {
    test('north: a yearly rule per clock change', () {
      expect(_blockOf('Europe/Berlin'), '''BEGIN:VTIMEZONE
TZID:Europe/Berlin
BEGIN:DAYLIGHT
DTSTART:20200329T020000
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
TZNAME:CEST
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU
END:DAYLIGHT
BEGIN:STANDARD
DTSTART:20201025T030000
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
TZNAME:CET
RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU
END:STANDARD
END:VTIMEZONE
''');
    });

    test('south: summer time over the new year', () {
      expect(_blockOf('Australia/Sydney'), '''BEGIN:VTIMEZONE
TZID:Australia/Sydney
BEGIN:STANDARD
DTSTART:20200405T030000
TZOFFSETFROM:+1100
TZOFFSETTO:+1000
TZNAME:AEST
RRULE:FREQ=YEARLY;BYMONTH=4;BYDAY=1SU
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:20201004T020000
TZOFFSETFROM:+1000
TZOFFSETTO:+1100
TZNAME:AEDT
RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=1SU
END:DAYLIGHT
END:VTIMEZONE
''');
    });

    test('no clock change, half an hour off', () {
      expect(_blockOf('Asia/Kolkata'), '''BEGIN:VTIMEZONE
TZID:Asia/Kolkata
BEGIN:STANDARD
DTSTART:19700101T000000
TZOFFSETFROM:+0530
TZOFFSETTO:+0530
TZNAME:IST
END:STANDARD
END:VTIMEZONE
''');
    });

    test('half an hour off with summer time', () {
      final block = _blockOf('Australia/Adelaide');
      expect(block, contains('TZOFFSETFROM:+1030\nTZOFFSETTO:+0930\n'));
      expect(block, contains('TZOFFSETFROM:+0930\nTZOFFSETTO:+1030\n'));
      expect('RRULE:'.allMatches(block), hasLength(2));
    });

    test('a zone without one rule lists each change', () {
      final block = _blockOf('America/Santiago');
      expect(block, isNot(contains('RRULE')));
      expect(block, contains('DTSTART:20200405T000000\n'));
      expect('BEGIN:STANDARD'.allMatches(block).length, greaterThan(15));
    });

    test(
      'a zone that stopped changing its clock ends with its last offset',
      () {
        final block = _blockOf('America/Mexico_City');
        expect(block, isNot(contains('RRULE')));
        expect(
          block,
          endsWith(
            'TZOFFSETTO:-0600\nTZNAME:CST\nEND:STANDARD\nEND:VTIMEZONE\n',
          ),
        );
      },
    );

    test('its bytes depend only on the zone', () {
      expect(_blockOf('Europe/Berlin'), _blockOf('Europe/Berlin'));
      final later = _added(
        birthday,
        'a',
        'Europe/Berlin',
        at: DateTime.utc(2031, 6, 1),
      );
      expect(
        Calendar.read(later)!.unitOf(const ZoneKey('Europe/Berlin'))!.text,
        _blockOf('Europe/Berlin'),
      );
    });
  });

  test('a calendar holds one block per zone', () {
    final twice = _added(
      _added(birthday, 'a', 'Asia/Tokyo'),
      'b',
      'Asia/Tokyo',
    );
    expect('TZID:Asia/Tokyo\n'.allMatches(twice), hasLength(1));
    expect(Calendar.read(twice)!.zones, {'Asia/Tokyo'});
  });

  test('the file of a new event names its zone and holds its block', () {
    final text = _added(birthday, 'a', 'Asia/Tokyo');
    expect(text, contains('DTSTART;TZID=Asia/Tokyo:20261103T090000\n'));
    expect(text, contains('BEGIN:VTIMEZONE\nTZID:Asia/Tokyo\n'));
  });

  test('a zone the data does not know adds no block', () {
    final text = _added(birthday, 'a', 'W. Europe Standard Time');
    expect(text, isNot(contains('VTIMEZONE')));
  });

  test('two devices adding one zone merge to one block, nothing lost', () {
    final mine = _added(birthday, 'a', 'Asia/Tokyo');
    final theirs = _added(birthday, 'b', 'Asia/Tokyo');
    final merged = const CalendarMerge().merge(mine, theirs) as MergedText;
    expect('BEGIN:VTIMEZONE'.allMatches(merged.text), hasLength(1));
    expect(merged.lost, isEmpty);
    expect(Calendar.read(merged.text)!.eventOf('b'), isNotNull);
  });

  test('a losing zone block of another app counts as nothing lost', () {
    final ours = _added(birthday, 'a', 'Asia/Tokyo');
    final theirs = ours.replaceAll('TZNAME:JST', 'TZNAME:Japan');
    final merged = const CalendarMerge().merge(ours, theirs) as MergedText;
    expect('BEGIN:VTIMEZONE'.allMatches(merged.text), hasLength(1));
    expect(merged.lost, isEmpty);
  });

  test('two blocks of one zone in a file read print back as they were', () {
    final blocks = exported.replaceFirst(
      'BEGIN:VEVENT\nUID:dentist',
      'BEGIN:VTIMEZONE\nTZID:Europe/Berlin\nBEGIN:STANDARD\n'
          'DTSTART:19701025T030000\nTZOFFSETFROM:+0200\nTZOFFSETTO:+0100\n'
          'TZNAME:CET\nEND:STANDARD\nEND:VTIMEZONE\n'
          'BEGIN:VEVENT\nUID:dentist',
    );
    final calendar = Calendar.read(blocks)!;
    expect(calendar.text, blocks);
    expect(
      calendar.unitOf(const ZoneKey('Europe/Berlin'))!.parts,
      hasLength(2),
    );
    final merged = const CalendarMerge().merge(blocks, exported) as MergedText;
    expect(merged.lost, isEmpty);
    expect(Calendar.read(merged.text)!.text, merged.text);
  });

  group('the time a new or changed event gets', () {
    final wall = DateTime.utc(2026, 11, 3, 9);

    test('a new one is in the device zone', () {
      expect(
        timeAt(wall, allDay: false, deviceZone: 'Europe/Berlin'),
        Zoned('Europe/Berlin', wall),
      );
    });

    test('an unknown or missing device zone gives floating', () {
      expect(
        timeAt(wall, allDay: false, deviceZone: 'Nowhere/City'),
        Floating(wall),
      );
      expect(timeAt(wall, allDay: false), Floating(wall));
    });

    test('a changed one keeps its own zone, or floats', () {
      expect(
        timeAt(
          wall,
          allDay: false,
          was: Zoned('America/New_York', DateTime.utc(2026)),
          deviceZone: 'Europe/Berlin',
        ),
        Zoned('America/New_York', wall),
      );
      expect(
        timeAt(
          wall,
          allDay: false,
          was: Floating(DateTime.utc(2026)),
          deviceZone: 'Europe/Berlin',
        ),
        Floating(wall),
      );
    });

    test('a day turned into a time takes the device zone', () {
      expect(
        timeAt(
          wall,
          allDay: false,
          was: AllDay(DateTime.utc(2026)),
          deviceZone: 'Asia/Tokyo',
        ),
        Zoned('Asia/Tokyo', wall),
      );
      expect(
        timeAt(wall, allDay: true, deviceZone: 'Asia/Tokyo'),
        AllDay(wall),
      );
    });
  });

  group('the same kind of time at a moment', () {
    final moment = DateTime.utc(2026, 11, 3, 14);

    test('stays in its zone', () {
      expect(
        Zoned('America/New_York', DateTime.utc(2026)).sameKindAt(moment),
        Zoned('America/New_York', DateTime.utc(2026, 11, 3, 9)),
      );
      expect(
        Zoned('Asia/Tokyo', DateTime.utc(2026)).sameKindAt(moment),
        Zoned('Asia/Tokyo', DateTime.utc(2026, 11, 3, 23)),
      );
    });

    test('UTC, floating and days follow the moment', () {
      expect(UtcTime(DateTime.utc(2026)).sameKindAt(moment), UtcTime(moment));
      final local = moment.toLocal();
      expect(Floating(DateTime.utc(2026)).sameKindAt(moment), Floating(local));
      expect(AllDay(DateTime.utc(2026)).sameKindAt(moment), AllDay(local));
    });
  });
}
