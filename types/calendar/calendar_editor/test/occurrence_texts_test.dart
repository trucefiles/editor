import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/ui/occurrence_texts.dart';

void main() {
  final calendar = Calendar.read(
    'BEGIN:VCALENDAR\nVERSION:2.0\n'
    'BEGIN:VEVENT\nUID:a\nDTSTART;VALUE=DATE:20261103\n'
    'DTEND;VALUE=DATE:20261104\nSUMMARY:Trip\nEND:VEVENT\n'
    'BEGIN:VEVENT\nUID:b\nDTSTART;VALUE=DATE:20261105\n'
    'DTEND;VALUE=DATE:20261106\nEND:VEVENT\n'
    'BEGIN:VEVENT\nUID:c\nDTSTART;VALUE=DATE:20261109\n'
    'DTEND;VALUE=DATE:20261112\nSUMMARY:Fair\nEND:VEVENT\n'
    'END:VCALENDAR\n',
  )!;
  final [trip, untitled, fair] = occurrences(
    calendar,
    DateTime(2026, 11),
    DateTime(2026, 12),
  );
  String day(DateTime start, {required bool allDay}) =>
      '${start.day}.${allDay ? '' : ' time'}';

  test('a line gives the day, then the title as the views show it', () {
    expect(occurrenceLine(trip, day), '3.  Trip');
    expect(occurrenceLine(untitled, day), '5.  (No title)');
    expect(occurrenceTitle(untitled), '(No title)');
  });

  test('a day says all day; days on end also their last day', () {
    const words = DefaultMaterialLocalizations();
    expect(timesOf(words, trip, use24Hour: true), 'All day');
    expect(timesOf(words, fair, use24Hour: true), 'All day, until Nov 11');
  });

  group('own clock', () {
    const words = DefaultMaterialLocalizations();

    /// The own-clock line of an event from [start] to [end], as written
    /// in a file; the tests run on a UTC clock.
    String? ownOf(String start, String end) {
      final calendar = Calendar.read(
        'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:a\n'
        '$start\n$end\nSUMMARY:Flight\nEND:VEVENT\nEND:VCALENDAR\n',
      )!;
      final [occurrence] = occurrences(
        calendar,
        DateTime(2026, 11),
        DateTime(2026, 12),
      );
      return ownTimesOf(words, occurrence, use24Hour: true);
    }

    test('two zones: each time in its own', () {
      expect(
        ownOf(
          'DTSTART;TZID=Europe/Berlin:20261103T100000',
          'DTEND;TZID=America/New_York:20261103T130000',
        ),
        '10:00 Europe/Berlin – 13:00 America/New York',
      );
    });

    test('a UTC time shows on the device clock, as "local time"', () {
      final start = DateTime.utc(2026, 11, 3, 9).toLocal();
      String two(int value) => '$value'.padLeft(2, '0');
      expect(
        ownOf(
          'DTSTART:20261103T090000Z',
          'DTEND;TZID=Asia/Tokyo:20261104T080000',
        ),
        '${two(start.hour)}:${two(start.minute)} local time – '
        'Nov 4 08:00 Asia/Tokyo',
      );
    });

    test('one zone, ending another day', () {
      expect(
        ownOf(
          'DTSTART;TZID=America/New_York:20261103T220000',
          'DTEND;TZID=America/New_York:20261104T010000',
        ),
        'In America/New York: 22:00 – Nov 4 01:00',
      );
    });

    test('none on the device clock, a zone showing the same, or a day', () {
      expect(
        ownOf('DTSTART:20261103T100000Z', 'DTEND:20261103T110000Z'),
        isNull,
      );
      expect(ownOf('DTSTART:20261103T100000', 'DTEND:20261103T110000'), isNull);
      expect(
        ownOf(
          'DTSTART;TZID=Europe/London:20261103T100000',
          'DTEND;TZID=Europe/London:20261103T110000',
        ),
        isNull,
      );
      expect(
        ownOf('DTSTART;VALUE=DATE:20261103', 'DTEND;VALUE=DATE:20261104'),
        isNull,
      );
    });
  });
}
