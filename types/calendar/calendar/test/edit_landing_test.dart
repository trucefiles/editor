import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

final _at = DateTime.utc(2026, 11, 1, 12);

const _weekly =
    'BEGIN:VCALENDAR\nVERSION:2.0\n'
    'BEGIN:VEVENT\nUID:run\nDTSTART:20261102T100000\n'
    'DTEND:20261102T110000\nRRULE:FREQ=WEEKLY\nSUMMARY:Run\nEND:VEVENT\n'
    'END:VCALENDAR\n';

final _calendar = Calendar.read(_weekly)!;

/// The second Monday's run, as the form started from it.
final _second = Floating(DateTime(2026, 11, 9, 10));
final _from = EventDraft.at(_calendar.eventOf('run')!, _second);

final _typed = EventDraft(
  summary: 'Long run',
  start: _from.start,
  end: _from.end,
  repeat: _from.repeat,
);

ChangeOccurrence get _changeOne =>
    ChangeOccurrence('run', _second, _typed, from: _from, at: _at);

ChangeSeries get _changeAll => ChangeSeries(
  'run',
  _typed.occurrenceAt(_from.start, _from.end),
  from: _from,
  at: _at,
);

/// [_calendar] after [edit] made elsewhere.
Calendar _after(CalendarEdit edit) => applyEdit(_calendar, edit);

void main() {
  test('a change of an event that is there lands as it is', () {
    for (final edit in [_changeOne, _changeAll]) {
      final landed = landing(_calendar, edit, newUid: 'new');
      expect((landed.edit, landed.gone), (edit, null));
    }
  });

  test('a change of a deleted event is saved as a new event', () {
    final deleted = _after(DeleteEvent('run', at: _at));
    for (final edit in [_changeOne, _changeAll]) {
      final landed = landing(deleted, edit, newUid: 'new');
      expect(landed.gone, GoneMeanwhile.event);
      final added = landed.edit as AddEvent;
      expect((added.uid, added.draft.summary), ('new', 'Long run'));
    }
  });

  test('a change of a date the series no longer has is saved as a new '
      'event of that date alone', () {
    final series = EventDraft.of(_calendar.eventOf('run')!.series);
    final moved = _after(
      ChangeSeries(
        'run',
        EventDraft(
          summary: series.summary,
          start: Floating(DateTime(2026, 11, 2, 18)),
          end: Floating(DateTime(2026, 11, 2, 19)),
          repeat: series.repeat,
        ),
        from: series,
        at: _at,
      ),
    );
    final dateDeleted = _after(DeleteOccurrence('run', _second, at: _at));
    for (final calendar in [moved, dateDeleted]) {
      final landed = landing(calendar, _changeOne, newUid: 'new');
      expect(landed.gone, GoneMeanwhile.date);
      final added = landed.edit as AddEvent;
      expect((added.draft.summary, added.draft.repeat), ('Long run', null));
    }
  });

  test('a changed date is still there', () {
    final changed = _after(_changeOne);
    final landed = landing(changed, _changeOne, newUid: 'new');
    expect(landed.gone, isNull);
  });
}
