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
    'END:VCALENDAR\n',
  )!;
  final [trip, untitled] = occurrences(
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
}
