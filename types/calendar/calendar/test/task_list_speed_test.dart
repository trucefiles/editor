import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'task_lists.dart';

/// The budget for the tasks list of five busy calendars, on the JIT that
/// tests run on. It is built when the Tasks view shows, again on a new
/// day. It took about 85 ms here, as long as
/// a month of the same calendars in the month view: the cost is the
/// recurrence library walking each series from its first date, which both
/// pay. Before, a fixed walk of a year ahead per series came on top.
/// CI runners took about 270 ms, so the budget leaves the same margin
/// over a local run as the month budget does.
const _listBudget = Duration(milliseconds: 400);

/// The budget for the tasks list again after a change of one of five
/// busy calendars (e.g. a box checked): only that one is walked again.
/// It took about 20 ms here; the same margin as [_listBudget].
const _changeBudget = Duration(milliseconds: 80);

/// A calendar well past normal use: 200 single tasks, 20 daily series
/// running since 2024 and one hourly since October, with the dailies'
/// last three weeks checked off, up to a week ago.
Calendar _busy(int calendar) {
  final tasks = [
    for (var index = 0; index < 200; index++)
      'BEGIN:VTODO\nUID:t$calendar-$index\nSUMMARY:Task\n'
          'DUE;VALUE=DATE:2026${(index % 12 + 1).toString().padLeft(2, '0')}'
          '15\nEND:VTODO\n',
    for (var index = 0; index < 20; index++)
      'BEGIN:VTODO\nUID:d$calendar-$index\nSUMMARY:Daily\n'
          'DUE:20240101T090000\nRRULE:FREQ=DAILY\nEND:VTODO\n',
    'BEGIN:VTODO\nUID:h$calendar\nSUMMARY:Hourly\n'
        'DUE:20261001T090000\nRRULE:FREQ=HOURLY\nEND:VTODO\n',
  ];
  final read = Calendar.read(
    'BEGIN:VCALENDAR\nVERSION:2.0\n${tasks.join()}END:VCALENDAR\n',
  )!;
  // The dailies' last three weeks checked off, up to a week ago.
  return [
    for (var index = 0; index < 20; index++)
      for (var day = 20; day < 41; day++)
        CheckTask(
          'd$calendar-$index',
          Floating(DateTime.utc(2026, 10, day, 9)),
          done: true,
          at: DateTime.utc(2026, 11, 10),
        ),
  ].fold(read, applyEdit);
}

void main() {
  test('the tasks list of five busy calendars comes within budget', () {
    final calendars = {
      for (var index = 0; index < 5; index++) index: _busy(index),
    };
    final times = [
      for (var day = 10; day < 21; day++)
        () {
          final watch = Stopwatch()..start();
          final list = taskListOf(calendars, DateTime(2026, 11, day));
          expect(list.overdue, isNotEmpty);
          return watch.elapsed;
        }(),
    ]..sort();

    expect(times[times.length ~/ 2], lessThan(_listBudget));
  });

  test('the tasks list after a change of one busy calendar comes within '
      'budget', () {
    final today = DateTime(2026, 11, 17);
    final entries = {
      for (var index = 0; index < 5; index++)
        index: calendarTaskEntries(_busy(index), today),
    };
    final changed = _busy(0);
    final times = [
      for (var run = 0; run < 11; run++)
        () {
          final watch = Stopwatch()..start();
          final list = taskList({
            ...entries,
            0: calendarTaskEntries(changed, today),
          }, today);
          expect(list.overdue, isNotEmpty);
          return watch.elapsed;
        }(),
    ]..sort();

    expect(times[times.length ~/ 2], lessThan(_changeBudget));
  });
}
