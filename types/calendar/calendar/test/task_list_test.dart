import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

Calendar _with(String items) =>
    Calendar.read('BEGIN:VCALENDAR\nVERSION:2.0\n${items}END:VCALENDAR\n')!;

String _task(String uid, {String due = '', String more = ''}) =>
    'BEGIN:VTODO\nUID:$uid\nSUMMARY:$uid\n'
    '${due.isEmpty ? '' : 'DUE$due\n'}${more}END:VTODO\n';

final _today = DateTime(2026, 11, 17);

List<String> _titles(List<TaskRow<String>> rows) => [
  for (final row in rows) row.entry.part.summary,
];

void main() {
  test('open tasks group by when they are due, each group by due time', () {
    final list = taskList({
      'home': _with(
        '${_task('later', due: ';VALUE=DATE:20261120')}'
        '${_task('long ago', due: ':20250101T090000')}'
        '${_task('today', due: ':20261117T180000')}'
        '${_task('yesterday', due: ';VALUE=DATE:20261116')}'
        '${_task('some day')}'
        '${_task('morning', due: ':20261117T080000')}',
      ),
    }, _today);
    expect(_titles(list.overdue), ['long ago', 'yesterday']);
    expect(_titles(list.today), ['morning', 'today']);
    expect(_titles(list.later), ['later']);
    expect(_titles(list.noDate), ['some day']);
    expect(list.done, isEmpty);
  });

  test('a repeating task shows once: its oldest open date of the last 30 '
      'days, else its next one', () {
    final daily = _task(
      'water plants',
      due: ':20261101T090000',
      more: 'RRULE:FREQ=DAILY\n',
    );
    final list = taskList({'home': _with(daily)}, _today);
    expect(_titles(list.overdue), ['water plants']);
    expect(list.overdue.single.entry.due, DateTime(2026, 11, 1, 9));
    expect(list.today, isEmpty);

    // All dates up to yesterday checked off.
    var calendar = _with(daily);
    for (var day = 1; day < 17; day++) {
      calendar = applyEdit(
        calendar,
        CheckTask(
          'water plants',
          Floating(DateTime.utc(2026, 11, day, 9)),
          done: true,
          at: DateTime.utc(2026, 11, day, 10),
        ),
      );
    }
    final caughtUp = taskList({'home': calendar}, _today);
    expect(caughtUp.overdue, isEmpty);
    expect(caughtUp.today.single.entry.due, DateTime(2026, 11, 17, 9));
    expect(caughtUp.today.single.entry.date, isNotNull);
    expect(caughtUp.done, hasLength(16));
    expect(
      caughtUp.done.first.entry.due,
      DateTime(2026, 11, 16, 9),
      reason: 'the latest first',
    );
  });

  test('a repeating task with no open date in the last 30 days shows its '
      'next one', () {
    final list = taskList({
      'home': _with(
        _task(
          'renew passport',
          due: ';VALUE=DATE:20260601',
          more: 'RRULE:FREQ=YEARLY\n',
        ),
      ),
    }, _today);
    expect(list.overdue, isEmpty, reason: 'June is more than 30 days ago');
    expect(list.later.single.entry.due, DateTime(2027, 6));
  });

  test('a task that repeats every two years shows its next date, however '
      'far', () {
    final list = taskList({
      'home': _with(
        _task(
          'new tyres',
          due: ';VALUE=DATE:20260301',
          more: 'RRULE:FREQ=YEARLY;INTERVAL=2\n',
        ),
      ),
    }, _today);
    expect(list.later.single.entry.due, DateTime(2028, 3));
  });

  test('a series done as a whole shows once among the done', () {
    final list = taskList({
      'home': _with(
        _task(
          'stretch',
          due: ';VALUE=DATE:20261101',
          more:
              'RRULE:FREQ=DAILY\nSTATUS:COMPLETED\n'
              'COMPLETED:20261116T090000Z\n',
        ),
      ),
    }, _today);
    expect(_titles(list.done), ['stretch']);
  });

  test('done ones by when they were done, the latest first', () {
    final list = taskList({
      'home': _with(
        '${_task('due yesterday', due: ';VALUE=DATE:20261116', more: 'COMPLETED:20261110T090000Z\n')}'
        '${_task('long overdue', due: ';VALUE=DATE:20261001', more: 'COMPLETED:20261117T090000Z\n')}',
      ),
    }, _today);
    expect(_titles(list.done), ['long overdue', 'due yesterday']);
  });

  test('a series done as a whole shows no open date', () {
    final list = taskList({
      'home': _with(
        _task(
          'stretch',
          due: ';VALUE=DATE:20261101',
          more: 'RRULE:FREQ=DAILY\nSTATUS:COMPLETED\n',
        ),
      ),
    }, _today);
    expect([...list.overdue, ...list.today, ...list.later], isEmpty);
  });

  test('done tasks of the last 30 days, and ones done without a date; one '
      'done at no known time counts as long ago', () {
    final list = taskList({
      'home': _with(
        '${_task('some time', more: 'STATUS:COMPLETED\n')}'
        '${_task('old', due: ':20260901T090000', more: 'STATUS:COMPLETED\n')}'
        '${_task('recent', due: ':20261110T090000', more: 'STATUS:COMPLETED\n')}'
        '${_task('undated', more: 'COMPLETED:20261115T090000Z\n')}'
        '${_task('long done', more: 'COMPLETED:20260115T090000Z\n')}',
      ),
    }, _today);
    expect(_titles(list.done)..sort(), ['recent', 'undated']);
  });

  test('a task due long ago and checked today stays among the done', () {
    final list = taskList({
      'home': _with(
        _task(
          'late',
          due: ';VALUE=DATE:20260901',
          more: 'STATUS:COMPLETED\nCOMPLETED:20261117T090000Z\n',
        ),
      ),
    }, _today);
    expect(_titles(list.done), ['late']);
  });

  test('rows tell their calendar; deleted and cancelled tasks are left out', () {
    final list = taskList({
      'home': _with(_task('a', due: ';VALUE=DATE:20261120')),
      'work': _with(
        '${_task('b', due: ';VALUE=DATE:20261121')}'
        '${_task('c', due: ';VALUE=DATE:20261121', more: 'STATUS:CANCELLED\n')}'
        '${_task('d', due: ';VALUE=DATE:20261121', more: 'X-TRUCE-DELETED:TRUE\n')}',
      ),
    }, _today);
    expect([for (final row in list.later) row.calendar], ['home', 'work']);
  });
}
