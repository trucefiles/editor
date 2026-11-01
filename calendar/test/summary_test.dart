import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'samples.dart';

final _at = DateTime.utc(2026, 11, 1, 12);

void main() {
  test('cards show the name, and the next occurrences or the cycle', () {
    final summary = const CalendarSupport().summary(birthday, maxLines: 5);
    expect((summary.title, summary.firstLine), ('Birthdays', 'Birthdays'));
    final preview = summary.preview(
      CalendarPreview(
        now: DateTime(2026, 11),
        occurrenceLine: (occurrence) =>
            '${occurrence.start.year} ${occurrence.part.summary}',
        cycleLine: (cycle, today) => 'day ${cycle.dayOfCycle(today)}',
        count: 2,
      ),
    );
    expect(preview, '2027 Ann', reason: 'a year ahead at most');
    final health = const CalendarSupport().summary(
      applyEdit(
        Calendar.read(newCalendarText('Me', health: true))!,
        AddEvent(
          'p@t',
          EventDraft.health(
            const Period(PeriodFlow.light),
            DateTime.utc(2026, 10, 30),
          ),
          at: _at,
        ),
      ).text,
      maxLines: 5,
    );
    expect(
      health.preview(
        CalendarPreview(
          now: DateTime(2026, 11, 1),
          occurrenceLine: (_) => '',
          cycleLine: (cycle, today) => 'day ${cycle.dayOfCycle(today)}',
        ),
      ),
      'day 3',
    );
  });
}
