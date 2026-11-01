import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

List<DateTime> _run(DateTime first, int days) => [
  for (final day in Iterable<int>.generate(days))
    DateTime.utc(first.year, first.month, first.day + day),
];

void main() {
  test('nothing to predict before a period is written', () {
    expect(predictCycle(const [], DateTime(2026, 11)), isNull);
  });

  test('one period: the standard 28 day cycle, its own length unknown', () {
    final cycle = predictCycle(
      _run(DateTime.utc(2026, 10, 1), 4),
      DateTime(2026, 10, 10),
    )!;
    expect(cycle.lastStart, DateTime.utc(2026, 10, 1));
    expect(cycle.cycleLength, 28);
    expect(cycle.periodLength, 4, reason: 'the only run so far');
    expect(cycle.nextStart, DateTime.utc(2026, 10, 29));
    expect(cycle.ovulation, DateTime.utc(2026, 10, 15));
    expect(cycle.fertileWindow.first, DateTime.utc(2026, 10, 10));
    expect(cycle.fertileWindow.last, DateTime.utc(2026, 10, 16));
    expect(cycle.dayOfCycle(DateTime(2026, 10, 10)), 10);
    expect(cycle.daysUntilNext(DateTime(2026, 10, 10)), 19);
  });

  test(
    'the mean of the cycles and periods so far; a one-day gap is one run',
    () {
      final days = [
        ..._run(DateTime.utc(2026, 7, 1), 5),
        ..._run(DateTime.utc(2026, 7, 31), 3),
        // A day left out inside a period.
        ..._run(DateTime.utc(2026, 8, 4), 1),
        ..._run(DateTime.utc(2026, 9, 1), 4),
      ];
      final cycle = predictCycle(days, DateTime(2026, 9, 3))!;
      expect(cycle.lastStart, DateTime.utc(2026, 9, 1));
      // 30 and 32 days.
      expect(cycle.cycleLength, 31);
      // 5 days, then 5 (the 31st to the 4th): the latest run may go on.
      expect(cycle.periodLength, 5);
      expect(cycle.nextPeriod, hasLength(5));
    },
  );

  test('days after today are left out', () {
    final cycle = predictCycle([
      ..._run(DateTime.utc(2026, 10, 1), 3),
      DateTime.utc(2026, 12, 1),
    ], DateTime(2026, 10, 5))!;
    expect(cycle.lastStart, DateTime.utc(2026, 10, 1));
  });

  test("a calendar's period days come from its period entries", () {
    final calendar = [
      AddEvent(
        'p@t',
        EventDraft.health(const Period(Flow.light), DateTime.utc(2026, 10, 1)),
        at: DateTime.utc(2026, 10, 1),
      ),
      AddEvent(
        's@t',
        EventDraft.health(
          const Symptom('Cramps', level: 2),
          DateTime.utc(2026, 10, 1),
        ),
        at: DateTime.utc(2026, 10, 1),
      ),
    ].fold(Calendar.read(newCalendarText('Me', health: true))!, applyEdit);
    expect(periodDays(calendar), [DateTime.utc(2026, 10, 1)]);
    expect(
      calendar.eventOf('s@t')!.series.health,
      const Symptom('Cramps', level: 2),
    );
  });
}
