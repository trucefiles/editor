import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

void main() {
  test('counts events and tasks, a repeat once, deleted ones left out', () {
    final calendar = Calendar.read(
      [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'BEGIN:VEVENT',
        'UID:a',
        'DTSTART;VALUE=DATE:20261101',
        'RRULE:FREQ=WEEKLY',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:a',
        'RECURRENCE-ID;VALUE=DATE:20261108',
        'DTSTART;VALUE=DATE:20261109',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:b',
        'DTSTART;VALUE=DATE:20261102',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:gone',
        'DTSTART;VALUE=DATE:20261103',
        'X-TRUCE-DELETED:TRUE',
        'END:VEVENT',
        'BEGIN:VTODO',
        'UID:t',
        'SUMMARY:Call',
        'END:VTODO',
        'END:VCALENDAR',
        '',
      ].join('\n'),
    )!;

    expect(calendar.counts, (events: 2, tasks: 1));
  });
}
