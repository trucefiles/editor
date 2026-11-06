import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'samples.dart';

final _at = DateTime.utc(2026, 11, 1, 12);

final _gym = AddEvent(
  'gym@t',
  EventDraft(
    summary: 'Gym',
    start: Floating(DateTime(2026, 11, 3, 18)),
    end: Floating(DateTime(2026, 11, 3, 19)),
  ),
  at: _at,
);

final _later = _at.add(const Duration(minutes: 1));

const _gymKey = UidKey.event('gym@t');

final _tokyoCall = AddEvent(
  'call@t',
  EventDraft(
    summary: 'Call',
    start: Zoned('Asia/Tokyo', DateTime(2026, 11, 3, 9)),
    end: Zoned('Asia/Tokyo', DateTime(2026, 11, 3, 10)),
  ),
  at: _at,
);

final _annRenamed = ChangeSeries(
  'ann@truce',
  EventDraft(
    summary: 'Ann (birthday)',
    start: AllDay(DateTime(2020, 3, 12)),
    end: AllDay(DateTime(2020, 3, 13)),
    repeat: const SimpleRepeat(Frequency.yearly),
  ),
  from: annDraft,
  at: _at,
);

MachineRun<
  CalendarMessage,
  CalendarState,
  CalendarOwnerEvent,
  CalendarSaveTimer
>
_run(String text) =>
    MachineRun.of(calendarMachine(text, version: const Version(1)));

/// The texts sent to the file owner so far.
List<String> _sent(
  MachineRun<Object?, Object?, CalendarOwnerEvent, Object?> run,
) => [
  for (final event in run.events)
    if (event case CalendarNotice(notice: ToFile(input: Edited(:final text))))
      text,
];

/// What shows goes to the file owner, as after a typing pause, so a
/// file may hold it from then on.
void _saved(
  MachineRun<Object?, Object?, CalendarOwnerEvent, CalendarSaveTimer> run,
) => run.send(
  run
      .all<CalendarSaveTimer>()
      .lastWhere((timer) => timer.delay == SaveTimer.pause.delay)
      .done,
);

void main() {
  test('an edit shows at once and is one undo step', () {
    final run = _run(birthday)..send(EditCalendar(_gym, newUid: 'new@t'));
    expect(run.state.calendar!.eventOf('gym@t'), isNotNull);
    expect(run.state.status.canUndo, isTrue);
    expect(run.state.status.unsent, isTrue);

    _saved(run);
    run.send(CalendarRequest(const Undo(), at: _at));
    expect(
      run.state.calendar!.eventOf('gym@t')!.series.deleted,
      isTrue,
      reason: 'undone as a delete, so a merge does not bring it back',
    );
    run.send(CalendarRequest(const Redo(), at: _at));
    final gym = run.state.calendar!.eventOf('gym@t')!.series;
    expect((gym.deleted, gym.summary), (false, 'Gym'));
  });

  test('an undo step keeps only the units the edit changed', () {
    final machine = calendarMachine(birthday, version: const Version(1));
    final step = machine.step(
      machine.state,
      machine.work,
      EditCalendar(_tokyoCall, newUid: 'new@t'),
    );
    final undo = step.work.history.undos.single.step as UnitsChanged;
    const keys = [UidKey.event('call@t'), ZoneKey('Asia/Tokyo')];
    expect(undo.before, {for (final key in keys) key: null});
    expect(undo.after.keys, keys);
    expect(
      undo.after[keys.first],
      same(step.state.calendar!.unitOf(keys.first)),
      reason: 'the unit shown, not a copy',
    );
  });

  test('undo and redo touch only the events of their step', () {
    final run = _run(birthday)
      ..send(EditCalendar(_gym, newUid: 'new@t'))
      ..send(EditCalendar(_annRenamed, newUid: 'new@t'));
    _saved(run);
    final gym = run.state.calendar!.unitOf(_gymKey)!.text;

    run.send(CalendarRequest(const Undo(), at: _later));
    expect(run.state.calendar!.eventOf('ann@truce')!.series.summary, 'Ann');
    expect(run.state.calendar!.unitOf(_gymKey)!.text, gym, reason: 'its bytes');

    run.send(CalendarRequest(const Undo(), at: _later));
    expect(run.state.calendar!.eventOf('gym@t')!.series.deleted, isTrue);
    run
      ..send(CalendarRequest(const Redo(), at: _later))
      ..send(CalendarRequest(const Redo(), at: _later));
    final calendar = run.state.calendar!;
    expect(
      [for (final event in calendar.events) event.series.summary],
      ['Ann (birthday)', 'Gym'],
    );
    expect(calendar.eventOf('gym@t')!.series.deleted, isFalse);
  });

  test('undoing a new event keeps the block of its zone, which its marker '
      'names', () {
    final run = _run(birthday)..send(EditCalendar(_tokyoCall, newUid: 'new@t'));
    _saved(run);
    run.send(CalendarRequest(const Undo(), at: _later));
    final calendar = run.state.calendar!;
    expect(calendar.eventOf('call@t')!.series.deleted, isTrue);
    expect(calendar.zones, {'Asia/Tokyo'});

    run.send(CalendarRequest(const Redo(), at: _later));
    expect(run.state.calendar!.eventOf('call@t')!.series.deleted, isFalse);
    expect(run.state.calendar!.zones, {'Asia/Tokyo'});
  });

  test('an event added and undone before any file got it leaves nothing, '
      'so a new calendar is not written', () {
    final start = newCalendarText('');
    final run = _run(start)
      ..send(EditCalendar(_tokyoCall, newUid: 'new@t'))
      ..send(CalendarRequest(const Undo(), at: _later));
    expect(run.state.calendar!.eventOf('call@t'), isNull);
    expect(run.state.calendar!.zones, {'Asia/Tokyo'}, reason: 'zones stay');

    run.send(CalendarRequest(const Redo(), at: _later));
    expect(run.state.calendar!.eventOf('call@t')!.series.deleted, isFalse);

    final gym = _run(start)
      ..send(EditCalendar(_gym, newUid: 'new@t'))
      ..send(CalendarRequest(const Undo(), at: _later));
    expect(gym.state.text, start, reason: 'back to the start text');
  });

  test('a restored backup drops an event no file got', () {
    final run = _run(birthday)
      ..send(EditCalendar(_gym, newUid: 'new@t'))
      ..send(CalendarRequest(const ReplaceAll(birthday), at: _later));
    expect(run.state.calendar!.eventOf('gym@t'), isNull);
  });

  test('an edit that writes nothing is no step and no save', () {
    final run = _run(birthday)
      ..send(
        EditCalendar(AddEvent('ann@truce', annDraft, at: _at), newUid: 'new@t'),
      );
    expect(run.state.text, birthday);
    expect((run.state.status.canUndo, run.state.status.unsent), (false, false));
  });

  test('a restored backup without a zone keeps the zone block', () {
    final run = _run(birthday)..send(EditCalendar(_tokyoCall, newUid: 'new@t'));
    _saved(run);
    run.send(CalendarRequest(const ReplaceAll(birthday), at: _later));
    final calendar = run.state.calendar!;
    expect(calendar.eventOf('call@t')!.series.deleted, isTrue);
    expect(calendar.zones, {'Asia/Tokyo'});
  });

  test('a restore over a calendar is undone and redone, stamped', () {
    final run = _run(birthday)..send(EditCalendar(_tokyoCall, newUid: 'new@t'));
    _saved(run);
    run.send(CalendarRequest(const ReplaceAll(birthday), at: _later));

    run.send(CalendarRequest(const Undo(), at: _later));
    var calendar = run.state.calendar!;
    final call = calendar.eventOf('call@t')!.series;
    expect((call.deleted, call.summary), (false, 'Call'));
    expect(call.component.value('SEQUENCE'), '2', reason: 'above the marker');
    expect(calendar.zones, {'Asia/Tokyo'});

    run.send(CalendarRequest(const Redo(), at: _later));
    calendar = run.state.calendar!;
    expect(calendar.eventOf('call@t')!.series.deleted, isTrue);
    expect(calendar.eventOf('ann@truce')!.series.summary, 'Ann');
    expect(calendar.zones, {'Asia/Tokyo'});
  });

  test('a restore brings back other units as the backup has them, and '
      'drops those it has not', () {
    String withUnits(String units) =>
        birthday.replaceFirst('END:VCALENDAR', '${units}END:VCALENDAR');
    const todoA = 'BEGIN:VTODO\nUID:todo@t\nSUMMARY:Buy milk\nEND:VTODO\n';
    const todoB = 'BEGIN:VTODO\nUID:todo@t\nSUMMARY:Buy bread\nEND:VTODO\n';
    const note = 'BEGIN:VJOURNAL\nSUMMARY:No uid\nEND:VJOURNAL\n';
    final backup = withUnits(todoA);
    final run = _run(withUnits('$todoB$note'))
      ..send(CalendarRequest(ReplaceAll(backup), at: _later));
    expect(run.state.text, backup, reason: 'not stamped, the note gone');
  });

  test('what an undo brings back wins over the text it undid', () {
    final rename = ChangeSeries(
      'ann@truce',
      EventDraft(
        summary: 'Ann (birthday)',
        start: AllDay(DateTime(2020, 3, 12)),
        end: AllDay(DateTime(2020, 3, 13)),
        repeat: const SimpleRepeat(Frequency.yearly),
      ),
      from: annDraft,
      at: _at,
    );
    final run = _run(birthday)..send(EditCalendar(rename, newUid: 'new@t'));
    // Saved, then reached another device, before the undo.
    final undone = run.state.text;
    run.send(
      CalendarRequest(const Undo(), at: _at.add(const Duration(minutes: 1))),
    );

    final merged = (const CalendarMerge().merge(
      undone,
      run.state.text,
    ) as MergedText).text;
    expect(Calendar.read(merged)!.eventOf('ann@truce')!.series.summary, 'Ann');
    expect(merged, contains('SEQUENCE:2\n'), reason: 'above both');
  });

  test('a restored backup wins over the text it replaced', () {
    final run = _run(birthday)..send(EditCalendar(_gym, newUid: 'new@t'));
    _saved(run);
    final edited = run.state.text;
    run.send(
      CalendarRequest(
        const ReplaceAll(birthday),
        at: _at.add(const Duration(minutes: 1)),
      ),
    );

    final merged = (const CalendarMerge().merge(
      edited,
      run.state.text,
    ) as MergedText).text;
    expect(
      Calendar.read(merged)!.eventOf('gym@t')!.series.deleted,
      isTrue,
      reason: 'the backup had no gym',
    );
  });

  test('undo and redo over a backup that is no calendar show each text', () {
    final run = _run(birthday)
      ..send(CalendarRequest(const ReplaceAll('not a calendar'), at: _at));
    expect((run.state.text, run.state.calendar), ('not a calendar', null));

    run.send(CalendarRequest(const Undo(), at: _at));
    expect(run.state.calendar!.name, 'Birthdays');
    run.send(CalendarRequest(const Redo(), at: _at));

    expect((run.state.text, run.state.calendar), ('not a calendar', null));
  });

  test('the text goes to the file owner after the pause, as typing does', () {
    final run = _run(birthday)..send(EditCalendar(_gym, newUid: 'new@t'));
    expect(_sent(run), isEmpty);
    final pause = run.all<CalendarSaveTimer>().firstWhere(
      (timer) => timer.delay == SaveTimer.pause.delay,
    );
    run.send(pause.done);
    expect(_sent(run).single, contains('SUMMARY:Gym'));
  });

  test('a text that is no calendar shows and takes no edits', () {
    final run = _run('# Notes\n')..send(EditCalendar(_gym, newUid: 'new@t'));
    expect((run.state.text, run.state.calendar), ('# Notes\n', null));
    expect(run.state.status.canUndo, isFalse);
  });

  test('both merged, as the user picked, show', () {
    final run = _run(birthday)
      ..send(EditCalendar(_gym, newUid: 'new@t'))
      ..send(
        CalendarRequest(SecureEditor(Ticket(), SecureReason.hide), at: _at),
      );
    final merged = applyEdit(
      Calendar.read(_sent(run).single)!,
      DeleteEvent('ann@truce', at: _at),
    );
    run.send(
      CalendarRequest(
        FromFile(Picked(merged.text, version: const Version(2), rev: 1)),
        at: _at,
      ),
    );
    expect(run.state.calendar!.eventOf('ann@truce')!.series.deleted, isTrue);
    expect(run.state.status.canUndo, isFalse);
  });

  test('an edit of an event deleted meanwhile is saved as a new one, '
      'and says so', () {
    final run = _run(birthday)
      ..send(
        EditCalendar(DeleteEvent('ann@truce', at: _at), newUid: 'unused@t'),
      );
    final rename = ChangeSeries(
      'ann@truce',
      EventDraft(
        summary: 'Ann (birthday)',
        start: annDraft.start,
        end: annDraft.end,
        repeat: annDraft.repeat,
      ),
      from: annDraft,
      at: _at,
    );
    run.send(EditCalendar(rename, newUid: 'new@t'));

    expect(
      run.state.calendar!.eventOf('new@t')!.series.summary,
      'Ann (birthday)',
    );
    expect(run.events.whereType<SavedAsNew>().map((saved) => saved.gone), [
      GoneMeanwhile.event,
    ]);
  });

  test('typing a name is one undo step, which an event edit ends', () {
    final run = _run(newCalendarText(''))
      ..send(const RenameCalendar('H'))
      ..send(const RenameCalendar('Ho'))
      ..send(const RenameCalendar('Home'));
    expect(run.state.calendar!.name, 'Home');
    expect(run.state.text, newCalendarText('Home'));
    expect(run.state.status.unsent, isTrue);

    run
      ..send(EditCalendar(_gym, newUid: 'new@t'))
      ..send(const RenameCalendar('Home!'))
      ..send(CalendarRequest(const Undo(), at: _later));
    expect(run.state.calendar!.name, 'Home');
    run.send(CalendarRequest(const Undo(), at: _later));
    expect(
      run.state.calendar!.eventOf('gym@t'),
      isNull,
      reason: 'never sent, so in no file',
    );
    run.send(CalendarRequest(const Undo(), at: _later));
    expect(run.state.calendar!.name, '');
    expect(run.state.status.canUndo, isFalse);

    run.send(CalendarRequest(const Redo(), at: _later));
    expect(run.state.calendar!.name, 'Home');
  });

  test('the same name, or a text that is no calendar, takes no rename', () {
    final run = _run(birthday)..send(const RenameCalendar('Birthdays'));
    expect(run.state.status.canUndo, isFalse);
    final none = _run('no calendar')..send(const RenameCalendar('X'));
    expect(
      (none.state.text, none.state.status.canUndo),
      ('no calendar', false),
    );
  });

  test('a rename keeps the units and reads nothing again', () {
    final run = _run(birthday);
    final before = run.state.calendar!;
    run.send(const RenameCalendar('Family'));
    final shown = run.state.calendar!;
    expect(shown.showsSameDaysAs(before), isTrue);
    expect(run.state.summary.calendar, same(shown));
    expect(run.state.text, shown.text);
  });

  test('typing a name in a large calendar takes no pass over it per key', () {
    // About 2 MB; each key printed the whole file before.
    final events = [
      for (final n in Iterable<int>.generate(20000))
        'BEGIN:VEVENT\nUID:$n\nDTSTART:20260101T100000Z\n'
            'SUMMARY:Event $n with a few words\nEND:VEVENT\n',
    ];
    final run = _run('BEGIN:VCALENDAR\n${events.join()}END:VCALENDAR\n');
    final watch = Stopwatch()..start();
    for (final n in Iterable<int>.generate(1000)) {
      run.send(RenameCalendar('Home $n'));
    }
    // Budget: 1000 keys in a second; with a pass per key they took over
    // ten.
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    expect(run.state.calendar!.name, 'Home 999');
  });
}
