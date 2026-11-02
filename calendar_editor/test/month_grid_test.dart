import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

void main() {
  test('a month grid shows whole weeks from the first weekday', () {
    // November 2026 starts on a Sunday and ends on a Monday.
    final november = DateTime(2026, 11);
    expect(gridDays(november, DateTime.sunday % 7), (
      first: DateTime(2026, 11, 1),
      end: DateTime(2026, 12, 6),
    ));
    expect(gridDays(november, DateTime.monday), (
      first: DateTime(2026, 10, 26),
      end: DateTime(2026, 12, 7),
    ));
  });

  test('a day counts each event that shows on it', () {
    EventDraft draft(DateTime start, DateTime end) =>
        EventDraft(summary: 'x', start: Floating(start), end: Floating(end));
    final calendar = [
      AddEvent(
        'a',
        draft(DateTime.utc(2026, 11, 2, 22), DateTime.utc(2026, 11, 3, 2)),
        at: DateTime.utc(2026, 11),
      ),
      AddEvent(
        'b',
        draft(DateTime.utc(2026, 11, 3, 9), DateTime.utc(2026, 11, 4)),
        at: DateTime.utc(2026, 11),
      ),
    ].fold(Calendar.read(newCalendarText('Home'))!, applyEdit);

    expect(
      countsByDay(
        occurrences(calendar, DateTime(2026, 11), DateTime(2026, 12)),
      ),
      {DateTime(2026, 11, 2): 1, DateTime(2026, 11, 3): 2},
      reason: 'an end at midnight is not a day of its own',
    );
  });
}
