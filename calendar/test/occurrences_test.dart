import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'samples.dart';

Calendar _with(String events) =>
    Calendar.read('BEGIN:VCALENDAR\n${events}END:VCALENDAR\n')!;

List<DateTime> _starts(Calendar calendar, DateTime from, DateTime to) => [
  for (final occurrence in occurrences(calendar, from, to)) occurrence.start,
];

void main() {
  test('a single event shows where it overlaps the range', () {
    final calendar = _with(
      'BEGIN:VEVENT\nUID:a\nDTSTART:20261110T090000\nDTEND:20261110T100000\n'
      'END:VEVENT\n',
    );
    expect(_starts(calendar, DateTime(2026, 11, 10), DateTime(2026, 11, 11)), [
      DateTime(2026, 11, 10, 9),
    ]);
    expect(
      _starts(calendar, DateTime(2026, 11, 11), DateTime(2026, 11, 12)),
      isEmpty,
    );
    expect(
      _starts(calendar, DateTime(2026, 11, 10, 9, 30), DateTime(2026, 11, 11)),
      hasLength(1),
      reason: 'still going on',
    );
  });

  test('a weekly series shows on its days, with the changed one moved', () {
    final calendar = Calendar.read(exported)!;
    final shown = occurrences(
      calendar,
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 20),
    );
    final swims = shown.where((each) => each.event.uid == 'swim@example.com');
    expect(
      [for (final swim in swims) swim.part.summary],
      ['Swimming', 'Swimming (late)', 'Swimming'],
    );
    // The late one starts an hour later.
    final late = swims.elementAt(1);
    expect(
      late.start.difference(swims.first.start),
      const Duration(days: 7, hours: 1),
    );
    expect(late.recurrence, isA<Zoned>());
  });

  test('a series with an end, a count and left-out days', () {
    final calendar = _with(
      'BEGIN:VEVENT\nUID:a\nDTSTART;VALUE=DATE:20261102\nRRULE:FREQ=DAILY;COUNT=5\n'
      'EXDATE;VALUE=DATE:20261104\nEND:VEVENT\n'
      'BEGIN:VEVENT\nUID:b\nDTSTART:20261102T080000\nDTEND:20261102T083000\n'
      'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;UNTIL=20261118T235959\nEND:VEVENT\n',
    );
    final days = occurrences(calendar, DateTime(2026, 11), DateTime(2026, 12));
    expect(
      [
        for (final day in days)
          if (day.event.uid == 'a') day.start.day,
      ],
      [2, 3, 5, 6],
    );
    expect(
      [
        for (final day in days)
          if (day.event.uid == 'b') day.start.day,
      ],
      [2, 4, 16, 18],
    );
  });

  test('a yearly all-day event shows every year', () {
    final calendar = Calendar.read(birthday)!;
    expect(_starts(calendar, DateTime(2030), DateTime(2031)), [
      DateTime(2030, 3, 12),
    ]);
    expect(
      occurrences(calendar, DateTime(2030), DateTime(2031)).single.allDay,
      isTrue,
    );
  });

  test('a rule the library cannot read shows its first occurrence', () {
    final calendar = _with(
      'BEGIN:VEVENT\nUID:a\nDTSTART:20261102T080000\nRRULE:FREQ=SOMETIMES\nEND:VEVENT\n',
    );
    expect(_starts(calendar, DateTime(2026), DateTime(2027)), [
      DateTime(2026, 11, 2, 8),
    ]);
  });

  test('a series that starts after the range shows nothing', () {
    final calendar = _with(
      'BEGIN:VEVENT\nUID:s@x\nDTSTART:20270105T090000\n'
      'DTEND:20270105T100000\nRRULE:FREQ=DAILY\nEND:VEVENT\n',
    );
    expect(
      occurrences(calendar, DateTime(2026, 11), DateTime(2026, 12)),
      isEmpty,
    );
  });

  test('repeats follow the rule as written, its end time too', () {
    final calendar = _with(
      'BEGIN:VEVENT\nUID:u@x\nDTSTART:20261102T090000\n'
      'DTEND:20261102T100000\nRRULE:FREQ=DAILY;UNTIL=20261104T080000\n'
      'END:VEVENT\n',
    );
    expect(_starts(calendar, DateTime(2026, 11), DateTime(2026, 12)), [
      DateTime(2026, 11, 2, 9),
      DateTime(2026, 11, 3, 9),
    ]);
  });

  test('cancelled events do not show', () {
    final calendar = _with(
      'BEGIN:VEVENT\nUID:a\nDTSTART:20261102T080000\nSTATUS:CANCELLED\nEND:VEVENT\n',
    );
    expect(occurrences(calendar, DateTime(2026), DateTime(2027)), isEmpty);
  });

  test('the occurrences of several calendars are joined by start', () {
    final shown = occurrencesOf(
      {
        'family': Calendar.read(exported)!,
        'birthdays': Calendar.read(birthday)!,
      },
      DateTime(2026, 11, 9),
      DateTime(2026, 11, 11),
    );
    expect([for (final each in shown) each.calendar], ['family', 'family']);
    expect(shown.first.occurrence.part.summary, 'Swimming');
  });

  test('a simple repeat reads and writes back as the form shows it', () {
    const rule = 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;UNTIL=20261118';
    final repeat = Repeat.of(rule) as SimpleRepeat;
    expect(repeat.days, {Weekday.mo, Weekday.we});
    expect(repeat.ruleFor(AllDay(DateTime(2026, 11, 2))), rule);
    expect(Repeat.of('FREQ=MONTHLY;BYDAY=2TU'), isA<OtherRepeat>());
  });
}
