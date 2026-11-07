import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'samples.dart';

void main() {
  test('a head read alone names the calendar as the whole read does', () {
    for (final text in [
      birthday,
      newCalendarText('Work'),
      newCalendarText('Me', health: true),
      newCalendarText(''),
      '\n${newCalendarText('After a blank line')}',
    ]) {
      final whole = Calendar.read(text)!;
      final head = CalendarHead.read(text)!;
      expect(
        (head.shownName, head.isHealth),
        (whole.shownName, whole.isHealth),
        reason: text,
      );
    }
  });

  test('a head stops at the first unit, so its events are not read', () {
    final head = CalendarHead.read(
      'BEGIN:VCALENDAR\nX-WR-CALNAME:Work\nBEGIN:VEVENT\n'
      'X-WR-CALNAME:Not this\nEND:VEVENT\nEND:VCALENDAR\n',
    )!;
    expect(head.text, 'BEGIN:VCALENDAR\nX-WR-CALNAME:Work\n');
    expect(head.name, 'Work');
  });

  test('a folded name and the standard name are read', () {
    expect(
      CalendarHead.read(
        'BEGIN:VCALENDAR\nX-WR-CALNAME:Long \n name\nEND:VCALENDAR\n',
      )!.name,
      'Long name',
    );
    expect(
      CalendarHead.read('BEGIN:VCALENDAR\nNAME:Team\nEND:VCALENDAR\n')!
          .shownName,
      'Team',
    );
  });

  test('a text that starts no calendar has no head', () {
    for (final text in [
      '',
      'not a calendar',
      'notes\nBEGIN:VCALENDAR\nEND:VCALENDAR\n',
      'BEGIN:VEVENT\nEND:VEVENT\n',
    ]) {
      expect(CalendarHead.read(text), isNull, reason: text);
    }
  });

  test('the title is the shown name, none if empty', () {
    expect(calendarTitle(CalendarHead.read(newCalendarText('Work'))!), 'Work');
    expect(calendarTitle(CalendarHead.read(newCalendarText(''))!), isNull);
  });

  test('the whole read takes its head from the head read, and prints '
      'back as it was', () {
    for (final text in [
      '\n\nBEGIN:VCALENDAR\nX-WR-CALNAME:Work\nEND:VCALENDAR\n',
      'BEGIN:VCALENDAR\nX-WR-CALNAME:Work\nbegin:VEVENT\nUID:a\n'
          'END:VEVENT\nEND:VCALENDAR',
    ]) {
      final whole = Calendar.read(text)!;
      expect(whole.head.text, CalendarHead.read(text)!.text);
      expect(whole.text, text);
      expect(whole.name, 'Work');
    }
  });

  test('time zones offered are places and UTC, not names that read '
      'wrong', () {
    expect(
      zoneNames,
      containsAll(['Europe/Berlin', 'America/New_York', 'Etc/UTC']),
    );
    expect(
      zoneNames.where((zone) => zone.startsWith('Etc/') || !zone.contains('/')),
      ['Etc/UTC'],
    );
    expect(zoneNames, isNot(contains('EST5EDT')));
  });

  test('a time names its zone only if it is in one', () {
    final wall = DateTime.utc(2026, 11, 3, 9);
    expect(Zoned('Europe/Berlin', wall).zone, 'Europe/Berlin');
    expect(
      [Floating(wall).zone, UtcTime(wall).zone, AllDay(wall).zone],
      [null, null, null],
    );
  });
}
