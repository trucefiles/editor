import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

/// The budget for one month's occurrences of a busy ten-year calendar,
/// on the JIT that tests run on. The calendar views work a month out
/// when it first shows, right after its page is built; turning every
/// event's time into this device's clock took about 75 ms here, a cheap
/// check on the written times first about 7.
const _monthBudget = Duration(milliseconds: 30);

/// Ten years of a busy calendar, well past normal use: four events a day
/// (14,600) and twenty weekly series.
Calendar _busy() {
  String two(int number) => number.toString().padLeft(2, '0');
  String at(DateTime day, int hour) =>
      '${day.year}${two(day.month)}${two(day.day)}T${two(hour)}0000';
  final days = [
    for (var day = 0; day < 3653; day++) DateTime(2020, 1, 1 + day),
  ];
  return Calendar.read(
    [
      'BEGIN:VCALENDAR\nVERSION:2.0\n',
      for (final (index, day) in days.indexed)
        for (final hour in [8, 10, 13, 16])
          'BEGIN:VEVENT\nUID:e$index-$hour\nDTSTART:${at(day, hour)}\n'
              'DTEND:${at(day, hour + 1)}\nSUMMARY:Event\nEND:VEVENT\n',
      for (var series = 0; series < 20; series++)
        'BEGIN:VEVENT\nUID:w$series\nDTSTART:20200106T180000\n'
            'DTEND:20200106T190000\nRRULE:FREQ=WEEKLY\nSUMMARY:Weekly\n'
            'END:VEVENT\n',
      'END:VCALENDAR\n',
    ].join(),
  )!;
}

void main() {
  test("a month's occurrences of a busy ten-year calendar come within "
      'budget', () {
    final calendar = _busy();
    final times = [
      for (var month = 1; month <= 21; month++)
        () {
          final watch = Stopwatch()..start();
          final shown = occurrences(
            calendar,
            DateTime(2025, month),
            DateTime(2025, month + 1),
          );
          expect(shown, isNotEmpty);
          return watch.elapsed;
        }(),
    ]..sort();

    expect(times[times.length ~/ 2], lessThan(_monthBudget));
  });
}
