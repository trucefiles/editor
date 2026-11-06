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

  CalendarPreview at(DateTime now) => CalendarPreview(
    now: now,
    occurrenceLine: (_) => '',
    cycleLine: (_, _) => '',
  );

  test('a calendar with no name has no title, and is named after its kind', () {
    for (final (health, kind) in [
      (false, 'Calendar'),
      (true, 'Health calendar'),
    ]) {
      final summary = CalendarSummary(newCalendarText('', health: health));
      expect((summary.title, summary.firstLine), (null, kind));
    }
    expect(CalendarSummary('no calendar').firstLine, '');
  });

  test('a calendar is searched from what was read, a text that is none as '
      'it is', () {
    final text = newCalendarText('Home')
        .replaceFirst('END:VCALENDAR', 'X-NOTE:not searched\nEND:VCALENDAR');
    expect(CalendarSummary(text).searchText, 'Home');
    expect(CalendarSummary('no calendar').searchText, 'no calendar');
  });

  test('a card holds until the first occurrence it shows ends', () {
    final summary = const CalendarSupport().summary(birthday, maxLines: 5);
    expect(summary.holdsUntil(at(DateTime(2026, 11))), DateTime(2027, 3, 13));
    expect(
      const CalendarSupport()
          .summary(newCalendarText('Empty'), maxLines: 5)
          .holdsUntil(at(DateTime(2026, 11))),
      isNull,
      reason: 'nothing it shows passes',
    );
  });

  test("a health calendar's card holds until the next day", () {
    final summary = const CalendarSupport().summary(
      newCalendarText('Me', health: true),
      maxLines: 5,
    );
    expect(
      summary.holdsUntil(at(DateTime(2026, 11, 1, 15))),
      DateTime(2026, 11, 2),
    );
  });

  test('search finds the name and the events, not the file words', () {
    final calendar = Calendar.read(exported)!;
    final summary = const CalendarSupport().summary(
      applyEdit(calendar, DeleteEvent('dentist@example.com', at: _at)).text,
      maxLines: 5,
    );
    expect(summary.searchText, contains('Family'));
    expect(summary.searchText, contains('Swimming (late)'));
    expect(summary.searchText, contains('blue bag'));
    expect(summary.searchText, isNot(contains('Dentist')));
    expect(summary.searchText, isNot(contains('VEVENT')));
    expect(
      const CalendarSupport().summary('not a calendar', maxLines: 5).searchText,
      'not a calendar',
    );
  });
}
