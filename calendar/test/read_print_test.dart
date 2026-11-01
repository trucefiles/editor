import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';

import 'samples.dart';

void main() {
  group('reading and printing', () {
    test('prints a calendar back byte for byte', () {
      for (final text in [exported, birthday, newCalendarText('Home')]) {
        expect(Calendar.read(text)!.text, text);
      }
    });

    test('keeps lines it does not read, between and after units', () {
      const text =
          'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:a\nEND:VEVENT\n'
          'X-STRAY:1\nEND:VCALENDAR\n\n';
      expect(Calendar.read(text)!.text, text);
    });

    test('a text without a last line break prints back without one', () {
      final text = birthday.substring(0, birthday.length - 1);
      expect(Calendar.read(text)!.text, text);
      expect(
        (const CalendarMerge().merge(text, text) as MergedText).text,
        text,
      );
    });

    test('groups a series with its changed occurrences in one unit', () {
      final calendar = Calendar.read(exported)!;
      final swim = calendar.eventOf('swim@example.com')!;
      expect(swim.series.summary, 'Swimming');
      expect(swim.changed.single.summary, 'Swimming (late)');
      expect(calendar.events.map((event) => event.uid), [
        'swim@example.com',
        'dentist@example.com',
      ]);
    });

    test('reads the calendar name, text values and unfolds lines', () {
      final calendar = Calendar.read(exported)!;
      expect(calendar.name, 'Family');
      expect(
        calendar.eventOf('swim@example.com')!.series.description,
        'Bring towels and the blue bag, and do not forget the membership '
        'card at the desk',
      );
    });

    test('is no calendar without its begin and end', () {
      expect(Calendar.read(''), isNull);
      expect(Calendar.read('# Notes\n'), isNull);
      expect(Calendar.read('BEGIN:VCALENDAR\nVERSION:2.0\n'), isNull);
      expect(
        Calendar.read('BEGIN:VCALENDAR\nBEGIN:VEVENT\nEND:VCALENDAR\n'),
        isNull,
      );
    });

    test('a new health calendar says so', () {
      final calendar = Calendar.read(newCalendarText('Me', health: true))!;
      expect((calendar.name, calendar.isHealth), ('Me', true));
      expect(Calendar.read(newCalendarText('Home'))!.isHealth, isFalse);
    });
  });

  group('times', () {
    test('reads days, floating, UTC and zoned times', () {
      final calendar = Calendar.read(exported)!;
      final swim = calendar.eventOf('swim@example.com')!.series;
      expect(swim.start, isA<Zoned>());
      // 17:00 in Berlin (summer time, UTC+2) is 15:00 UTC.
      expect(swim.start!.local, DateTime.utc(2026, 10, 5, 15).toLocal());
      final dentist = calendar.eventOf('dentist@example.com')!.series;
      expect(dentist.start, Floating(DateTime(2026, 11, 10, 9)));
      expect(dentist.start!.local, DateTime(2026, 11, 10, 9));
      final ann = Calendar.read(birthday)!.eventOf('ann@truce')!.series;
      expect((ann.allDay, ann.start!.local), (true, DateTime(2020, 3, 12)));
    });

    test('a zone it does not know reads as floating', () {
      const text =
          'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:a\n'
          'DTSTART;TZID=W. Europe Standard Time:20261110T090000\n'
          'END:VEVENT\nEND:VCALENDAR\n';
      final start = Calendar.read(text)!.eventOf('a')!.series.start!;
      expect(start.local, DateTime(2026, 11, 10, 9));
    });
  });
}
