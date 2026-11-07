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
}
