import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

final _at = DateTime.utc(2026, 11, 10, 12);

/// A task file as Thunderbird writes it: a monthly task from a start to
/// a due time two days later, with an alert before it is due.
const _thunderbird = '''BEGIN:VCALENDAR
PRODID:-//Mozilla.org/NONSGML Mozilla Calendar V1.1//EN
VERSION:2.0
BEGIN:VTODO
CREATED:20261020T090000Z
LAST-MODIFIED:20261020T090000Z
DTSTAMP:20261020T090000Z
UID:rent@thunderbird
SUMMARY:Pay rent
STATUS:NEEDS-ACTION
RRULE:FREQ=MONTHLY
DTSTART:20261101T090000
DUE:20261103T180000
X-MOZ-GENERATION:1
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER;VALUE=DURATION;RELATED=END:-PT15M
DESCRIPTION:Default Mozilla Description
END:VALARM
END:VTODO
END:VCALENDAR
''';

Calendar _with(String items) =>
    Calendar.read('BEGIN:VCALENDAR\nVERSION:2.0\n${items}END:VCALENDAR\n')!;

/// A task [uid] due as [due] says (a `DUE` line's value, with its
/// parameters), with [more] lines.
String _task(String uid, String due, {String more = ''}) =>
    'BEGIN:VTODO\nUID:$uid\nSUMMARY:$uid\nDUE$due\n${more}END:VTODO\n';

List<TaskOccurrence> _tasksIn(Calendar calendar, DateTime from, DateTime to) =>
    occurrences(calendar, from, to).whereType<TaskOccurrence>().toList();

final _november = (from: DateTime(2026, 11), to: DateTime(2026, 12));

void main() {
  group('reading', _reading);
  group('on the calendar', _shown);
  group('checking off', _checking);
  group('editing', _editing);
  group('when gone meanwhile', _gone);
}

void _reading() {
  test('a task of another app reads with its times, alert and state, and '
      'prints back byte for byte', () {
    final calendar = Calendar.read(_thunderbird)!;
    expect(calendar.text, _thunderbird);
    final task = calendar.taskOf('rent@thunderbird')!;
    expect(calendar.items, [task]);
    expect(calendar.events, isEmpty);
    final part = task.series;
    expect(part.summary, 'Pay rent');
    expect(part.due, Floating(DateTime.utc(2026, 11, 3, 18)));
    expect(part.anchor, Floating(DateTime.utc(2026, 11, 1, 9)));
    expect(part.alerts, [const Duration(minutes: 15)]);
    expect(part.repeat, const SimpleRepeat(Frequency.monthly));
    expect(part.done, isFalse);
  });

  test('done by its status or by when it was done', () {
    final calendar = _with(
      '${_task('a', ':20261110T090000', more: 'STATUS:COMPLETED\n')}'
      '${_task('b', ':20261110T090000', more: 'COMPLETED:20261109T080000Z\n')}'
      '${_task('c', ':20261110T090000', more: 'STATUS:IN-PROCESS\n')}',
    );
    expect(
      [for (final task in calendar.tasks) task.series.done],
      [true, true, false],
    );
  });

  test('a due time from a start and a length; none without either', () {
    final calendar = _with(
      'BEGIN:VTODO\nUID:a\nDTSTART:20261110T090000\nDURATION:PT2H\n'
      'END:VTODO\n'
      'BEGIN:VTODO\nUID:b\nSUMMARY:Some day\nEND:VTODO\n',
    );
    expect(
      calendar.taskOf('a')!.series.due,
      Floating(DateTime.utc(2026, 11, 10, 11)),
    );
    expect(calendar.taskOf('b')!.series.due, isNull);
  });
}

void _shown() {
  test('a task shows as the half hour up to its due time, or all day on its '
      'due day; one without a due time not at all', () {
    final calendar = _with(
      '${_task('time', ':20261110T180000')}'
      '${_task('day', ';VALUE=DATE:20261111')}'
      'BEGIN:VTODO\nUID:never\nEND:VTODO\n',
    );
    final shown = _tasksIn(calendar, _november.from, _november.to);
    expect([for (final task in shown) task.item.uid], ['time', 'day']);
    final (time, day) = (shown.first, shown.last);
    expect(time.start, DateTime(2026, 11, 10, 17, 30));
    expect(time.end, DateTime(2026, 11, 10, 18));
    expect(time.due, DateTime(2026, 11, 10, 18));
    expect(day.allDay, isTrue);
    expect(day.start, DateTime(2026, 11, 11));
    expect(day.due, DateTime(2026, 11, 11));
  });

  test("a repeating task's dates count from its start; each shows at its "
      'due time', () {
    final calendar = Calendar.read(_thunderbird)!;
    final shown = _tasksIn(calendar, DateTime(2026, 11), DateTime(2027, 1));
    expect(
      [for (final date in shown) date.due],
      [DateTime(2026, 11, 3, 18), DateTime(2026, 12, 3, 18)],
    );
    expect(shown.last.recurrence, Floating(DateTime.utc(2026, 12, 1, 9)));
  });

  test('a task that only starts shows where it starts, each date of its '
      'repeat, and is listed by date', () {
    final daily = _with(
      'BEGIN:VTODO\nUID:walk\nSUMMARY:Walk\nDTSTART;VALUE=DATE:20261101\n'
      'RRULE:FREQ=DAILY;COUNT=3\nEND:VTODO\n',
    );
    final shown = _tasksIn(daily, _november.from, _november.to);
    expect(
      [for (final date in shown) date.start],
      [DateTime(2026, 11), DateTime(2026, 11, 2), DateTime(2026, 11, 3)],
    );
    final list = taskList({'home': daily}, DateTime(2026, 11, 2));
    expect(list.noDate, isEmpty);
    expect(list.overdue.single.entry.date, AllDay(DateTime(2026, 11)));
  });

  test('a cancelled task and a deleted one show nowhere', () {
    final calendar = _with(
      '${_task('a', ':20261110T090000', more: 'STATUS:CANCELLED\n')}'
      '${_task('b', ':20261110T090000', more: 'X-TRUCE-DELETED:TRUE\n')}',
    );
    expect(_tasksIn(calendar, _november.from, _november.to), isEmpty);
  });
}

void _checking() {
  final single = _with(_task('milk', ':20261110T090000'));

  test('checking a task off says when; open again drops that', () {
    final done = applyEdit(
      single,
      CheckTask('milk', null, done: true, at: _at),
    );
    final part = done.taskOf('milk')!.series;
    expect(part.done, isTrue);
    expect(part.component.value('STATUS'), 'COMPLETED');
    expect(part.component.value('COMPLETED'), '20261110T120000Z');
    expect(part.component.value('PERCENT-COMPLETE'), '100');

    final open = applyEdit(
      done,
      CheckTask('milk', null, done: false, at: _at),
    ).taskOf('milk')!.series;
    expect(open.done, isFalse);
    expect(open.component.value('STATUS'), 'NEEDS-ACTION');
    expect(open.component.property('COMPLETED'), isNull);
    expect(open.component.property('PERCENT-COMPLETE'), isNull);
  });

  test('a check of what is checked already writes nothing', () {
    expect(
      writeEdit(single, CheckTask('milk', null, done: false, at: _at)).written,
      isEmpty,
    );
  });

  final monthly = Calendar.read(_thunderbird)!;
  final december = Floating(DateTime.utc(2026, 12, 1, 9));

  test('checking one date of a repeating task checks only that date, in a '
      'changed date of its own', () {
    final checked = applyEdit(
      monthly,
      CheckTask('rent@thunderbird', december, done: true, at: _at),
    );
    final task = checked.taskOf('rent@thunderbird')!;
    expect(task.series.done, isFalse);
    final date = task.changedAt(december)!;
    expect(date.done, isTrue);
    expect(date.due, Floating(DateTime.utc(2026, 12, 3, 18)));
    expect(date.component.property('RRULE'), isNull);
    final shown = _tasksIn(checked, DateTime(2026, 11), DateTime(2027, 1));
    expect([for (final date in shown) date.done], [false, true]);
    expect(shown.last.due, DateTime(2026, 12, 3, 18));
  });

  test('a date open again goes back to the series as it was; one changed '
      'otherwise stays, open', () {
    final checked = applyEdit(
      monthly,
      CheckTask('rent@thunderbird', december, done: true, at: _at),
    );
    final open = applyEdit(
      checked,
      CheckTask('rent@thunderbird', december, done: false, at: _at),
    );
    expect(open.taskOf('rent@thunderbird')!.changed, isEmpty);

    final renamed = applyEdit(
      checked,
      ChangeOccurrence(
        'rent@thunderbird',
        december,
        (ItemDraft.at(
          checked.taskOf('rent@thunderbird')!,
          december,
        ) as TaskDraft).withSummary('Pay rent (late)'),
        from: ItemDraft.at(checked.taskOf('rent@thunderbird')!, december),
        at: _at,
      ),
    );
    final kept = applyEdit(
      renamed,
      CheckTask('rent@thunderbird', december, done: false, at: _at),
    ).taskOf('rent@thunderbird')!.changedAt(december)!;
    expect(kept.summary, 'Pay rent (late)');
    expect(kept.done, isFalse);
  });

  test('in a file of changed dates only, a check of one checks that one', () {
    final dates = _with(
      'BEGIN:VTODO\nUID:gym\nSUMMARY:Gym\n'
      'RECURRENCE-ID;VALUE=DATE:20261102\nDUE;VALUE=DATE:20261102\n'
      'END:VTODO\n'
      'BEGIN:VTODO\nUID:gym\nSUMMARY:Gym\n'
      'RECURRENCE-ID;VALUE=DATE:20261109\nDUE;VALUE=DATE:20261109\n'
      'END:VTODO\n',
    );
    final second = AllDay(DateTime(2026, 11, 9));
    final task = applyEdit(
      dates,
      CheckTask('gym', second, done: true, at: _at),
    ).taskOf('gym')!;
    expect(task.series.done, isFalse);
    expect(task.changedAt(second)!.done, isTrue);
  });

  test('a date of a series done as a whole is opened in a changed date', () {
    final calendar = _with(
      _task(
        'daily',
        ':20261110T090000',
        more: 'RRULE:FREQ=DAILY\nSTATUS:COMPLETED\n',
      ),
    );
    final date = Floating(DateTime.utc(2026, 11, 11, 9));
    final open = applyEdit(
      calendar,
      CheckTask('daily', date, done: false, at: _at),
    ).taskOf('daily')!;
    expect(open.changedAt(date)!.done, isFalse);
    expect(open.series.done, isTrue);
  });
}

extension on TaskDraft {
  TaskDraft withSummary(String summary) => TaskDraft(
    summary: summary,
    due: due,
    start: start,
    description: description,
    location: location,
    repeat: repeat,
    alerts: alerts,
    color: color,
  );
}

void _editing() {
  test('a new task is open, due as drafted, its alert counted from when it '
      'is due', () {
    final calendar = applyEdit(
      _with(''),
      AddItem(
        'new@t',
        TaskDraft(
          summary: 'Call the bank',
          due: AllDay(DateTime(2026, 11, 12)),
          alerts: const [Duration(minutes: 15)],
        ),
        at: _at,
      ),
    );
    final task = calendar.taskOf('new@t')!.series;
    expect(task.component.name, 'VTODO');
    expect(task.done, isFalse);
    expect(task.component.value('STATUS'), 'NEEDS-ACTION');
    expect(task.due, AllDay(DateTime(2026, 11, 12)));
    expect(task.alerts, [const Duration(minutes: 15)]);
    expect(
      calendar.text,
      contains('TRIGGER;RELATED=END:-PT15M\n'),
      reason: 'other apps count it from when it is due',
    );
  });

  test("a new due time moves the task's start along, and its checked dates "
      'with it', () {
    final calendar = applyEdit(
      Calendar.read(_thunderbird)!,
      CheckTask(
        'rent@thunderbird',
        Floating(DateTime.utc(2026, 12, 1, 9)),
        done: true,
        at: _at,
      ),
    );
    final from =
        ItemDraft.of(calendar.taskOf('rent@thunderbird')!.series) as TaskDraft;
    final moved = applyEdit(
      calendar,
      ChangeSeries(
        'rent@thunderbird',
        from.withDue(Floating(DateTime.utc(2026, 11, 5, 18))),
        from: from,
        at: _at,
      ),
    ).taskOf('rent@thunderbird')!;
    expect(moved.series.start, Floating(DateTime.utc(2026, 11, 3, 9)));
    expect(moved.series.due, Floating(DateTime.utc(2026, 11, 5, 18)));
    expect(
      moved.changed.single.recurrenceId,
      Floating(DateTime.utc(2026, 12, 3, 9)),
    );
  });

  test('a change to a task without a date keeps what another device '
      'changed meanwhile', () {
    final opened = _with(
      'BEGIN:VTODO\nUID:tent\nSUMMARY:Tent\nDESCRIPTION:old\nEND:VTODO\n',
    );
    final from = ItemDraft.of(opened.taskOf('tent')!.series) as TaskDraft;
    final meanwhile = applyEdit(
      opened,
      ChangeSeries(
        'tent',
        TaskDraft(summary: 'Tent', description: 'from the other device'),
        from: from,
        at: _at,
      ),
    );
    final task = applyEdit(
      meanwhile,
      ChangeSeries(
        'tent',
        TaskDraft(summary: 'Fix the tent', description: 'old'),
        from: from,
        at: _at.add(const Duration(minutes: 1)),
      ),
    ).taskOf('tent')!.series;
    expect(
      (task.summary, task.description),
      ('Fix the tent', 'from the other device'),
    );
  });

  test('no due time: no start and no repeat either', () {
    final from = TaskDraft(
      summary: 'Rent',
      due: Floating(DateTime.utc(2026, 11, 3, 18)),
      start: Floating(DateTime.utc(2026, 11, 1, 9)),
      repeat: const SimpleRepeat(Frequency.monthly),
    );
    final none = from.withDue(null);
    expect((none.due, none.start, none.repeat), (null, null, null));
    final day = from.withDue(AllDay(DateTime(2026, 11, 4)));
    expect(day.start, isNull, reason: 'a time start for a day');
  });

  test('a drag moves a date of a task to be due where it ends', () {
    final calendar = Calendar.read(_thunderbird)!;
    final december = _tasksIn(
      calendar,
      DateTime(2026, 12),
      DateTime(2027),
    ).single;
    final moved = applyEdit(
      calendar,
      occurrenceMovedTo(
        december,
        DateTime(2026, 12, 4, 9, 30),
        DateTime(2026, 12, 4, 10),
      )(_at),
    );
    final date = moved
        .taskOf('rent@thunderbird')!
        .changedAt(december.recurrence!)!;
    expect(date.due, Floating(DateTime.utc(2026, 12, 4, 10)));
    expect(date.start, Floating(DateTime.utc(2026, 12, 2, 1)));
  });

  test('a deleted task stays as a marker of a task; a deleted date is left '
      'out', () {
    final calendar = Calendar.read(_thunderbird)!;
    final deleted = applyEdit(
      calendar,
      DeleteItem(const UidKey.task('rent@thunderbird'), at: _at),
    );
    final marker = deleted.taskOf('rent@thunderbird')!.series;
    expect((marker.deleted, marker.component.name), (true, 'VTODO'));
    expect(_tasksIn(deleted, DateTime(2026, 11), DateTime(2027)), isEmpty);

    final dateGone = applyEdit(
      calendar,
      DeleteOccurrence(
        const UidKey.task('rent@thunderbird'),
        Floating(DateTime.utc(2026, 12, 1, 9)),
        at: _at,
      ),
    );
    expect(_tasksIn(dateGone, DateTime(2026, 11), DateTime(2027)).length, 1);
  });
}

void _gone() {
  final calendar = Calendar.read(_thunderbird)!;
  final deleted = applyEdit(
    calendar,
    DeleteItem(const UidKey.task('rent@thunderbird'), at: _at),
  );
  final december = Floating(DateTime.utc(2026, 12, 1, 9));

  test('a check of a task deleted meanwhile changes nothing, and says so', () {
    final landed = landing(
      deleted,
      CheckTask('rent@thunderbird', december, done: true, at: _at),
      newUid: 'new@t',
    );
    expect((landed.edit, landed.gone), (null, GoneMeanwhile.task));
  });

  test('a check of a date the task no longer has changes nothing', () {
    final dateGone = applyEdit(
      calendar,
      DeleteOccurrence(
        const UidKey.task('rent@thunderbird'),
        december,
        at: _at,
      ),
    );
    final landed = landing(
      dateGone,
      CheckTask('rent@thunderbird', december, done: true, at: _at),
      newUid: 'new@t',
    );
    expect((landed.edit, landed.gone), (null, GoneMeanwhile.taskDate));
  });

  test('a change of a task deleted meanwhile is saved as a new task', () {
    final from = ItemDraft.of(calendar.taskOf('rent@thunderbird')!.series);
    final landed = landing(
      deleted,
      ChangeSeries('rent@thunderbird', from, from: from, at: _at),
      newUid: 'new@t',
    );
    expect(landed.gone, GoneMeanwhile.task);
    expect(
      applyEdit(deleted, landed.edit!).taskOf('new@t')!.series.summary,
      'Pay rent',
    );
  });
}
