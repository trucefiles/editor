import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'recurrence_fixtures.dart';

Calendar _with(String events) =>
    Calendar.read('BEGIN:VCALENDAR\n${events}END:VCALENDAR\n')!;

/// A calendar of one series [uid] from [start] (as `DTSTART` writes it,
/// e.g. `;TZID=Asia/Tokyo:20261201T080000`) by [rule], with [more] lines.
Calendar _series(String start, String rule, {String more = ''}) => _with(
  'BEGIN:VEVENT\nUID:s\nDTSTART$start\nRRULE:$rule\n${more}END:VEVENT\n',
);

/// The wall clocks of [calendar]'s occurrences from [from] to [to], as
/// written (`20261201T080000`, or `20261201` for days).
List<String> _walls(Calendar calendar, DateTime from, DateTime to) => [
  for (final occurrence in occurrences(calendar, from, to))
    _text(occurrence.recurrence!),
];

String _text(CalendarTime time) {
  String two(int value) => '$value'.padLeft(2, '0');
  final wall = time.wall;
  final day = '${wall.year}${two(wall.month)}${two(wall.day)}';
  return time is AllDay
      ? day
      : '${day}T${two(wall.hour)}${two(wall.minute)}${two(wall.second)}';
}

void main() {
  group('repeats come as dateutil reads them', () {
    for (final (name, start, rule, expected) in dateutilCases) {
      final day = start.length == 8;
      for (final zone in [null, 'Europe/Berlin']) {
        test('$name${zone == null ? '' : ' in $zone'}', () {
          final calendar = _series(
            day
                ? ';VALUE=DATE:$start'
                : '${zone == null ? '' : ';TZID=$zone'}:$start',
            rule,
          );
          expect(
            _walls(calendar, DateTime(1990), DateTime(2100)).take(25),
            expected,
          );
        });
      }
    }
  });

  test('a UTC end east of UTC keeps the last occurrence', () {
    // As Google writes it: the last occurrence, 10 December 08:00 in
    // Tokyo, in UTC (the day before).
    final calendar = _series(
      ';TZID=Asia/Tokyo:20261208T080000',
      'FREQ=DAILY;UNTIL=20261209T230000Z',
    );
    expect(_walls(calendar, DateTime(2026, 12), DateTime(2027)), [
      '20261208T080000',
      '20261209T080000',
      '20261210T080000',
    ]);
  });

  test('a UTC end west of UTC keeps the last occurrence', () {
    // The last occurrence, 10 December 20:00 in New York, is 11 December
    // in UTC.
    final calendar = _series(
      ';TZID=America/New_York:20261208T200000',
      'FREQ=DAILY;UNTIL=20261211T010000Z',
    );
    expect(_walls(calendar, DateTime(2026, 12), DateTime(2027)), [
      '20261208T200000',
      '20261209T200000',
      '20261210T200000',
    ]);
  });

  test('an end day on a time of day includes that day', () {
    final calendar = _series(':20261108T090000', 'FREQ=DAILY;UNTIL=20261110');
    expect(_walls(calendar, DateTime(2026, 11), DateTime(2026, 12)), [
      '20261108T090000',
      '20261109T090000',
      '20261110T090000',
    ]);
  });

  test('an end time on a series of days ends on its day', () {
    final calendar = _series(
      ';VALUE=DATE:20261108',
      'FREQ=DAILY;UNTIL=20261110T120000',
    );
    expect(_walls(calendar, DateTime(2026, 11), DateTime(2026, 12)), [
      '20261108',
      '20261109',
      '20261110',
    ]);
  });

  test('a series of days ends on the day its end names, in any zone', () {
    for (final until in ['20250110T235959Z', '20250110T000000Z']) {
      final calendar = _series(
        ';VALUE=DATE:20250106',
        'FREQ=DAILY;UNTIL=$until',
      );
      expect(
        _walls(calendar, DateTime(2025), DateTime(2025, 2)).last,
        '20250110',
      );
      expect(
        (calendar.events.single.series.repeat! as SimpleRepeat).until,
        DateTime.utc(2025, 1, 10),
      );
    }
  });

  test('a floating end on a zoned series is read on its own clock', () {
    final calendar = _series(
      ';TZID=Europe/Berlin:20250106T200000',
      'FREQ=DAILY;UNTIL=20250110T235959',
    );
    expect(_walls(calendar, DateTime(2025), DateTime(2025, 2)), hasLength(5));
    expect(
      (calendar.events.single.series.repeat! as SimpleRepeat).until,
      DateTime.utc(2025, 1, 10),
    );
  });

  test('a rule with a space after a comma shows its first occurrence', () {
    // As Exchange writes it.
    final calendar = _series(':20261102T090000', 'FREQ=WEEKLY;BYDAY=MO, TU');
    expect(_walls(calendar, DateTime(2026, 11), DateTime(2026, 12)), [
      '20261102T090000',
    ]);
  });

  test('a series keeps its clock time across a clock change', () {
    final calendar = _series(
      ';TZID=Europe/Berlin:20261024T090000',
      'FREQ=DAILY;COUNT=3',
    );
    final shown = occurrences(calendar, DateTime(2026, 10), DateTime(2026, 11));
    expect(
      [for (final each in shown) _text(each.recurrence!)],
      ['20261024T090000', '20261025T090000', '20261026T090000'],
    );
    expect(
      [for (final each in shown) each.start],
      [for (final each in shown) each.recurrence!.local],
    );
    // Summer time ends on the 25th: the 26th comes 25 hours after the
    // 25th's day before.
    expect(
      shown[2].start.toUtc().difference(shown[0].start.toUtc()),
      const Duration(hours: 49),
    );
  });

  test('extra dates of a series show too', () {
    final calendar = _series(
      ':20261102T090000',
      'FREQ=WEEKLY;COUNT=2',
      more: 'RDATE:20261104T090000\n',
    );
    expect(_walls(calendar, DateTime(2026, 11), DateTime(2026, 12)), [
      '20261102T090000',
      '20261104T090000',
      '20261109T090000',
    ]);
  });

  test('a series past the step limit shows what came so far', () {
    final calendar = _series(':20260101T000000', 'FREQ=MINUTELY');
    final shown = occurrences(calendar, DateTime(2026), DateTime(2026, 4));
    expect(shown, isNotEmpty);
    expect(shown.last.start.isBefore(DateTime(2026, 3, 15)), isTrue);
    expect(
      occurrences(calendar, DateTime(2026, 6), DateTime(2026, 7)),
      isEmpty,
    );
  });

  group('a repeat\'s end day', () {
    for (final (zone, written) in [
      ('Asia/Tokyo', 'UNTIL=20261210T145959Z'),
      ('America/New_York', 'UNTIL=20261211T045959Z'),
    ]) {
      test('is written as the end of the day in $zone, in UTC', () {
        final start = Zoned(zone, DateTime.utc(2026, 12, 1, 8));
        final repeat = SimpleRepeat(
          Frequency.daily,
          until: DateTime.utc(2026, 12, 10),
        );
        final rule = repeat.ruleFor(start);
        expect(rule, 'FREQ=DAILY;$written');
        expect(Repeat.of(rule, start), repeat);
      });
    }

    test('is the day of the last occurrence in its zone', () {
      final start = Zoned('Asia/Tokyo', DateTime.utc(2026, 12, 1, 8));
      // Google's end: 10 December 08:00 in Tokyo, in UTC.
      expect(
        (Repeat.of(
          'FREQ=DAILY;UNTIL=20261209T230000Z',
          start,
        ) as SimpleRepeat).until,
        DateTime.utc(2026, 12, 10),
      );
    });

    test('is a day or a floating end of day as the start is', () {
      final repeat = SimpleRepeat(
        Frequency.weekly,
        until: DateTime.utc(2026, 12, 10),
      );
      expect(
        repeat.ruleFor(AllDay(DateTime(2026, 12))),
        'FREQ=WEEKLY;UNTIL=20261210',
      );
      expect(
        repeat.ruleFor(Floating(DateTime(2026, 12, 1, 8))),
        'FREQ=WEEKLY;UNTIL=20261210T235959',
      );
    });
  });
}
