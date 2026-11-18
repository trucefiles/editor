import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

Calendar _with(String items) =>
    Calendar.read('BEGIN:VCALENDAR\nVERSION:2.0\n${items}END:VCALENDAR\n')!;

/// An alarm block: [trigger] is the `TRIGGER` line after `TRIGGER`.
String _alarm(String trigger, {String action = 'DISPLAY'}) =>
    'BEGIN:VALARM\nACTION:$action\nTRIGGER$trigger\nEND:VALARM\n';

String _event(String uid, String times, {String more = ''}) =>
    'BEGIN:VEVENT\nUID:$uid\nSUMMARY:$uid\n$times\n${more}END:VEVENT\n';

String _task(String uid, String times, {String more = ''}) =>
    'BEGIN:VTODO\nUID:$uid\nSUMMARY:$uid\n$times\n${more}END:VTODO\n';

/// The alerts of [calendar] in November 2026, as (title, when on this
/// device's clock).
List<(String, DateTime)> _november(Calendar calendar) => [
  for (final alert in alertsIn(
    calendar,
    DateTime(2026, 11),
    DateTime(2026, 12),
  ))
    (alert.title, alert.at.toLocal()),
];

void main() {
  test('counts from the start, the end, or a task\'s due time', () {
    final calendar = _with(
      _event(
            'start',
            'DTSTART:20261110T090000\nDTEND:20261110T100000',
            more: _alarm(':-PT15M'),
          ) +
          _event(
            'end',
            'DTSTART:20261111T090000\nDTEND:20261111T100000',
            more: _alarm(';RELATED=END:PT5M'),
          ) +
          _task(
            'due',
            'DUE:20261112T180000',
            more: _alarm(';RELATED=END:-PT1H'),
          ),
    );
    expect(_november(calendar), [
      ('start', DateTime(2026, 11, 10, 8, 45)),
      ('end', DateTime(2026, 11, 11, 10, 5)),
      ('due', DateTime(2026, 11, 12, 17)),
    ]);
  });

  test('a task\'s alert from its start counts from its start', () {
    final calendar = _with(
      _task(
        'rent',
        'DTSTART:20261110T090000\nDUE:20261112T180000',
        more: _alarm(':-PT30M'),
      ),
    );
    expect(_november(calendar), [('rent', DateTime(2026, 11, 10, 8, 30))]);
  });

  test('a day counts from its midnight; whole days on the calendar', () {
    final calendar = _with(
      _event(
        'birthday',
        'DTSTART;VALUE=DATE:20261120',
        more: _alarm(':-P1DT6H'),
      ),
    );
    expect(_november(calendar), [('birthday', DateTime(2026, 11, 18, 18))]);
  });

  test('a time in a zone rings at that moment', () {
    final calendar = _with(
      _event(
        'call',
        'DTSTART;TZID=America/New_York:20261110T090000\n'
            'DTEND;TZID=America/New_York:20261110T100000',
        more: _alarm(':-PT10M'),
      ),
    );
    expect(
      alertsIn(calendar, DateTime(2026, 11), DateTime(2026, 12)).single.at,
      DateTime.utc(2026, 11, 10, 13, 50),
    );
  });

  test('each date of a repeat rings, a changed date at its own time, a '
      'left out one not', () {
    final calendar = _with(
      _event(
            'standup',
            'DTSTART:20261102T090000\nDTEND:20261102T091500\n'
                'RRULE:FREQ=WEEKLY;COUNT=4\nEXDATE:20261109T090000',
            more: _alarm(':-PT5M'),
          ) +
          _event(
            'standup',
            'RECURRENCE-ID:20261116T090000\n'
                'DTSTART:20261116T110000\nDTEND:20261116T111500',
            more: _alarm(':-PT5M'),
          ),
    );
    expect(_november(calendar), [
      ('standup', DateTime(2026, 11, 2, 8, 55)),
      ('standup', DateTime(2026, 11, 16, 10, 55)),
      ('standup', DateTime(2026, 11, 23, 8, 55)),
    ]);
  });

  test('an alert long before its date is found', () {
    final calendar = _with(
      _event(
        'trip',
        'DTSTART:20261207T090000\nDTEND:20261207T100000',
        more: _alarm(':-P1W'),
      ),
    );
    expect(_november(calendar), [('trip', DateTime(2026, 11, 30, 9))]);
  });

  test('an alert at a fixed time rings then, its item far away', () {
    final calendar = _with(
      _task(
        'taxes',
        'DUE;VALUE=DATE:20270115',
        more: _alarm(';VALUE=DATE-TIME:20261120T080000Z'),
      ),
    );
    final alert = alertsIn(
      calendar,
      DateTime(2026, 11),
      DateTime(2026, 12),
    ).single;
    expect(alert.at, DateTime.utc(2026, 11, 20, 8));
    expect(alert.start, DateTime(2027, 1, 15));
  });

  test('an alert at a fixed time that other apps copied into each '
      'changed date rings once', () {
    const alarm = ';VALUE=DATE-TIME:20261110T080000Z';
    final calendar = _with(
      _event(
            'standup',
            'DTSTART:20261109T090000\nDTEND:20261109T093000\n'
                'RRULE:FREQ=DAILY;COUNT=5',
            more: _alarm(alarm),
          ) +
          _event(
            'standup',
            'RECURRENCE-ID:20261111T090000\nDTSTART:20261111T100000\n'
                'DTEND:20261111T103000',
            more: _alarm(alarm),
          ),
    );
    expect(alertsIn(calendar, DateTime(2026, 11), DateTime(2026, 12)), [
      isA<Alert>().having((alert) => alert.title, 'title', 'standup'),
    ]);
  });

  test('the form lists the alerts that ring, however their trigger is '
      'cased', () {
    final task = _with(
      _task(
        'due',
        'DUE:20261112T180000',
        more:
            _alarm(';related=end:-PT1H') +
            _alarm(':-PT1H', action: 'AUDIO') +
            _alarm(';VALUE=DATE-TIME:20261112T080000Z'),
      ),
    ).taskOf('due')!;
    expect(task.series.alerts, [const Duration(hours: 1)]);
    expect(task.series.alarms, hasLength(3));
  });

  test('only alarms that show or sound ring, each trigger once', () {
    final calendar = _with(
      _event(
        'dentist',
        'DTSTART:20261110T090000\nDTEND:20261110T100000',
        more:
            _alarm(':-PT15M') +
            _alarm(':-PT15M', action: 'AUDIO') +
            _alarm(':-PT1H', action: 'EMAIL'),
      ),
    );
    expect(_november(calendar), [('dentist', DateTime(2026, 11, 10, 8, 45))]);
  });

  test('done, cancelled and deleted ones stay silent', () {
    final calendar = _with(
      _task(
            'done',
            'DUE:20261112T180000\nSTATUS:COMPLETED',
            more: _alarm(';RELATED=END:-PT1H'),
          ) +
          _event(
            'cancelled',
            'DTSTART:20261110T090000\nSTATUS:CANCELLED',
            more: _alarm(':-PT15M'),
          ) +
          _task(
            'done fixed',
            'DUE:20261112T180000\nSTATUS:COMPLETED',
            more: _alarm(';VALUE=DATE-TIME:20261110T080000Z'),
          ),
    );
    expect(_november(calendar), isEmpty);
  });

  test('a checked date of a repeating task stays silent, the others ring', () {
    final calendar = _with(
      _task(
            'water',
            'DUE:20261102T180000\nRRULE:FREQ=WEEKLY;COUNT=2',
            more: _alarm(';RELATED=END:-PT1H'),
          ) +
          _task(
            'water',
            'RECURRENCE-ID:20261102T180000\nDUE:20261102T180000\n'
                'STATUS:COMPLETED',
            more: _alarm(';RELATED=END:-PT1H'),
          ),
    );
    expect(_november(calendar), [('water', DateTime(2026, 11, 9, 17))]);
  });

  test('outside the span: none; keys stay across reads', () {
    final text = _event(
      'dentist',
      'DTSTART:20261110T090000\nDTEND:20261110T100000',
      more: _alarm(':-PT15M'),
    );
    expect(
      alertsIn(_with(text), DateTime(2026, 11, 10, 8, 46), DateTime(2026, 12)),
      isEmpty,
    );
    final keys = [
      for (final _ in [1, 2])
        alertsIn(
          _with(text),
          DateTime(2026, 11),
          DateTime(2026, 12),
        ).single.key,
    ];
    expect(keys.toSet(), hasLength(1));
  });
}
