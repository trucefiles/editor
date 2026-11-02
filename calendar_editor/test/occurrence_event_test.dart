import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/views/occurrence_event.dart';

final _at = DateTime.utc(2026, 11, 1, 12);

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

  group('a drag', () {
    test('moves a single event, keeping its zone', () {
      final calendar = _read(
        _calendar(
          'BEGIN:VEVENT\nUID:b\nDTSTART;TZID=America/New_York:20261103T090000\n'
          'DTEND;TZID=America/New_York:20261103T100000\nSUMMARY:Call\n'
          'END:VEVENT\n',
        ),
      );
      final call = _november(calendar).single;
      final edit = movedTo(
        call,
        call.start.add(const Duration(hours: 2)),
        call.end.add(const Duration(hours: 3)),
      )(_at);

      final moved = applyEdit(calendar, edit).eventOf('b')!.series;
      expect(edit, isA<ChangeSeries>());
      expect(
        (moved.start, moved.end),
        (
          Zoned('America/New_York', DateTime.utc(2026, 11, 3, 11)),
          Zoned('America/New_York', DateTime.utc(2026, 11, 3, 13)),
        ),
      );
    });

    test('of one date of a series changes only that date', () {
      final calendar = _read(
        _calendar(
          'BEGIN:VEVENT\nUID:s\nDTSTART:20261102T090000\n'
          'DTEND:20261102T100000\nRRULE:FREQ=WEEKLY\nSUMMARY:Run\n'
          'END:VEVENT\n',
        ),
      );
      final second = _november(calendar)[1];
      final edited = applyEdit(
        calendar,
        movedTo(second, DateTime(2026, 11, 10, 7), DateTime(2026, 11, 10, 8))(
          _at,
        ),
      );

      expect(
        [for (final occurrence in _november(edited)) occurrence.start],
        [
          DateTime(2026, 11, 2, 9),
          DateTime(2026, 11, 10, 7),
          DateTime(2026, 11, 16, 9),
          DateTime(2026, 11, 23, 9),
          DateTime(2026, 11, 30, 9),
        ],
      );
      expect(edited.eventOf('s')!.changed.single.summary, 'Run');
    });

    test('of a changed date moves that changed one', () {
      final calendar = _read(
        _calendar(
          'BEGIN:VEVENT\nUID:s\nDTSTART:20261102T090000\n'
          'DTEND:20261102T100000\nRRULE:FREQ=WEEKLY;COUNT=2\nSUMMARY:Run\n'
          'END:VEVENT\nBEGIN:VEVENT\nUID:s\nRECURRENCE-ID:20261109T090000\n'
          'DTSTART:20261109T070000\nDTEND:20261109T080000\n'
          'SUMMARY:Early run\nEND:VEVENT\n',
        ),
      );
      final early = _november(calendar)
          .firstWhere((each) => each.part.summary == 'Early run');
      final edited = applyEdit(
        calendar,
        movedTo(early, DateTime(2026, 11, 9, 6), DateTime(2026, 11, 9, 7))(_at),
      );

      final changed = edited.eventOf('s')!.changed.single;
      expect(
        (changed.summary, changed.start),
        ('Early run', Floating(DateTime.utc(2026, 11, 9, 6))),
      );
    });

    test('of a day keeps it a day; its end at midnight is the day after '
        'its last', () {
      final calendar = _read(
        _calendar(
          'BEGIN:VEVENT\nUID:a\nDTSTART;VALUE=DATE:20261103\n'
          'DTEND;VALUE=DATE:20261104\nSUMMARY:Trip\nEND:VEVENT\n',
        ),
      );
      final trip = _november(calendar).single;
      final resized = applyEdit(
        calendar,
        movedTo(trip, DateTime(2026, 11, 3), DateTime(2026, 11, 6))(_at),
      ).eventOf('a')!.series;
      final dropped = applyEdit(
        calendar,
        movedTo(trip, DateTime(2026, 11, 5, 10), DateTime(2026, 11, 5, 11))(
          _at,
        ),
      ).eventOf('a')!.series;

      expect(
        (resized.start, resized.end),
        (AllDay(DateTime(2026, 11, 3)), AllDay(DateTime(2026, 11, 6))),
      );
      expect(
        (dropped.start, dropped.end),
        (AllDay(DateTime(2026, 11, 5)), AllDay(DateTime(2026, 11, 6))),
        reason: 'a day dropped on a time stays one day long',
      );
    });
  });
}
