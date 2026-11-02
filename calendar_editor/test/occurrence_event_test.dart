import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/views/occurrence_event.dart';

/// [text] read as a calendar.
Calendar _read(String text) => Calendar.read(text)!;

String _calendar(String events) =>
    'BEGIN:VCALENDAR\nVERSION:2.0\n${events}END:VCALENDAR\n';

/// The occurrences of [calendar] in November 2026.
List<Occurrence> _november(Calendar calendar) =>
    occurrences(calendar, DateTime(2026, 11), DateTime(2026, 12));

void main() {
  group('as kalender events', () {
    test('times on the device clock, days as all day, midnight to '
        'midnight', () {
      final calendar = _read(
        _calendar(
          'BEGIN:VEVENT\nUID:a\nDTSTART;VALUE=DATE:20261103\n'
          'DTEND;VALUE=DATE:20261105\nSUMMARY:Trip\nEND:VEVENT\n'
          'BEGIN:VEVENT\nUID:b\nDTSTART:20261103T090000Z\n'
          'DTEND:20261103T100000Z\nSUMMARY:Call\nEND:VEVENT\n',
        ),
      );
      final [trip, call] = eventsOf([
        for (final occurrence in _november(calendar))
          (calendar: 'home', occurrence: occurrence),
      ]);

      expect(
        (trip.isAllDay, trip.start, trip.end),
        (true, DateTime(2026, 11, 3).toUtc(), DateTime(2026, 11, 5).toUtc()),
      );
      expect(
        (call.isAllDay, call.start, call.end),
        (false, DateTime.utc(2026, 11, 3, 9), DateTime.utc(2026, 11, 3, 10)),
      );
      expect(call.calendar, 'home');
    });

    test('a broken end before the start shows as no length', () {
      final calendar = _read(
        _calendar(
          'BEGIN:VEVENT\nUID:a\nDTSTART:20261103T100000\n'
          'DTEND:20261103T090000\nSUMMARY:Odd\nEND:VEVENT\n',
        ),
      );
      final event = eventsOf([
        (calendar: 'home', occurrence: _november(calendar).single),
      ]).single;

      expect(event.end, event.start);
    });
  });
}
