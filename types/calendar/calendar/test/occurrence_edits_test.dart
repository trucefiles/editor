import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

final _at = DateTime.utc(2026, 11, 1, 12);

/// [text] read as a calendar.
Calendar _read(String text) => Calendar.read(text)!;

String _calendar(String events) =>
    'BEGIN:VCALENDAR\nVERSION:2.0\n${events}END:VCALENDAR\n';

/// The occurrences of [calendar] in November 2026.
List<Occurrence> _november(Calendar calendar) =>
    occurrences(calendar, DateTime(2026, 11), DateTime(2026, 12));

void main() {
  test('a series whose end is written on another clock keeps its length '
      'in its dates and in one date to edit', () {
    final calendar = _read(
      _calendar(
        'BEGIN:VEVENT\nUID:s\nDTSTART;TZID=Europe/Berlin:20261102T100000\n'
        'DTEND:20261102T100000Z\nRRULE:FREQ=WEEKLY\nSUMMARY:Run\n'
        'END:VEVENT\n',
      ),
    );
    final second = _november(calendar)[1];
    final draft = occurrenceDraft(second);

    expect(second.end.difference(second.start), const Duration(hours: 1));
    expect(
      draft.end.local.difference(draft.start.local),
      const Duration(hours: 1),
    );
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
      final edit = occurrenceMovedTo(
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
        occurrenceMovedTo(
          second,
          DateTime(2026, 11, 10, 7),
          DateTime(2026, 11, 10, 8),
        )(_at),
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
        occurrenceMovedTo(
          early,
          DateTime(2026, 11, 9, 6),
          DateTime(2026, 11, 9, 7),
        )(_at),
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
        occurrenceMovedTo(trip, DateTime(2026, 11, 3), DateTime(2026, 11, 6))(
          _at,
        ),
      ).eventOf('a')!.series;
      final dropped = applyEdit(
        calendar,
        occurrenceMovedTo(
          trip,
          DateTime(2026, 11, 5, 10),
          DateTime(2026, 11, 5, 11),
        )(_at),
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
