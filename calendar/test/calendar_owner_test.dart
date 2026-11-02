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

MachineRun<CalendarMessage, CalendarState, CalendarNotice, CalendarSaveTimer>
_run(String text) =>
    MachineRun.of(calendarMachine(text, version: const Version(1)));

/// The texts sent to the file owner so far.
List<String> _sent(MachineRun<Object?, Object?, CalendarNotice, Object?> run) =>
    [
      for (final notice in run.events)
        if (notice.notice case ToFile(input: Edited(:final text))) text,
    ];

void main() {
  test('an edit shows at once and is one undo step', () {
    final run = _run(birthday)..send(EditCalendar(_gym));
    expect(run.state.calendar!.eventOf('gym@t'), isNotNull);
    expect(run.state.status.canUndo, isTrue);
    expect(run.state.status.unsent, isTrue);

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

  test('what an undo brings back wins over the text it undid', () {
    final rename = ChangeSeries(
      'ann@truce',
      EventDraft(
        summary: 'Ann (birthday)',
        start: AllDay(DateTime(2020, 3, 12)),
        end: AllDay(DateTime(2020, 3, 13)),
        repeat: const SimpleRepeat(Frequency.yearly),
      ),
      at: _at,
    );
    final run = _run(birthday)..send(EditCalendar(rename));
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
    final run = _run(birthday)..send(EditCalendar(_gym));
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
    final run = _run(birthday)..send(EditCalendar(_gym));
    expect(_sent(run), isEmpty);
    final pause = run.all<CalendarSaveTimer>().firstWhere(
      (timer) => timer.delay == SaveTimer.pause.delay,
    );
    run.send(pause.done);
    expect(_sent(run).single, contains('SUMMARY:Gym'));
  });

  test('a text that is no calendar shows and takes no edits', () {
    final run = _run('# Notes\n')..send(EditCalendar(_gym));
    expect((run.state.text, run.state.calendar), ('# Notes\n', null));
    expect(run.state.status.canUndo, isFalse);
  });

  test('both merged, as the user picked, show', () {
    final run = _run(birthday)
      ..send(EditCalendar(_gym))
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
}
