import 'dart:convert';

import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'samples.dart';

final _at = DateTime.utc(2026, 11, 1, 12);

EventDraft _draft(String summary, DateTime start, {Repeat? repeat}) =>
    EventDraft(
      summary: summary,
      start: Floating(start),
      end: Floating(start.add(const Duration(hours: 1))),
      repeat: repeat,
    );

Calendar _edited(String text, CalendarEdit edit) =>
    applyEdit(Calendar.read(text)!, edit);

void main() {
  group('a repeat\'s last day', _repeatEnds);
  group("a series' start moved", _startMoves);
  group('a series of extra dates alone', _extraDatesOnly);

  test('an edit keeps a changed date whose date is unreadable', () {
    const unreadable =
        'BEGIN:VEVENT\nUID:ann@truce\nRECURRENCE-ID;VALUE=DATE:2021-03-12\n'
        'DTSTART;VALUE=DATE:20210313\nSUMMARY:Moved\nEND:VEVENT\n';
    final calendar = Calendar.read(
      birthday.replaceFirst('END:VCALENDAR', '${unreadable}END:VCALENDAR'),
    )!;
    final at = DateTime.utc(2027, 2, 10, 12);
    for (final edit in [
      DeleteOccurrence('ann@truce', AllDay(DateTime(2027, 3, 12)), at: at),
      ChangeSeries(
        'ann@truce',
        EventDraft(
          summary: 'Ann (birthday)',
          start: AllDay(DateTime(2020, 3, 12)),
          end: AllDay(DateTime(2020, 3, 13)),
          repeat: const SimpleRepeat(Frequency.yearly),
        ),
        from: annDraft,
        at: at,
      ),
    ]) {
      expect(applyEdit(calendar, edit).text, contains(unreadable));
    }
  });

  test('drafts are equal when every field is', () {
    final draft = _draft('Gym', DateTime(2026, 11, 3, 18));
    expect(_draft('Gym', DateTime(2026, 11, 3, 18)), draft);
    expect(_draft('Gym', DateTime(2026, 11, 3, 18)).hashCode, draft.hashCode);
    expect(_draft('Run', DateTime(2026, 11, 3, 18)), isNot(draft));
    expect(
      EventDraft(
        summary: 'Gym',
        start: draft.start,
        end: draft.end,
        alerts: const [Duration(minutes: 5)],
      ),
      isNot(draft),
    );
  });

  test('a new event is added at the end, stamped, floating', () {
    final calendar = _edited(
      birthday,
      AddEvent('new@truce', _draft('Gym', DateTime(2026, 11, 3, 18)), at: _at),
    );
    final unit = calendar.unitOf(const UidKey.event('new@truce'))!.text;
    expect(
      calendar.text,
      startsWith(birthday.replaceAll('END:VCALENDAR\n', '')),
    );
    expect(unit, contains('DTSTART:20261103T180000\n'));
    expect(unit, contains('LAST-MODIFIED:20261101T120000Z\n'));
    expect(unit, contains('DTSTAMP:20261101T120000Z\n'));
    expect(unit, contains('SEQUENCE:0\n'));
    expect(unit, contains('SUMMARY:Gym\n'));
  });

  test(
    'an edit leaves the other units and its untouched lines as they were',
    () {
      final calendar = Calendar.read(exported)!;
      final swim = calendar.eventOf('swim@example.com')!;
      final draft = EventDraft.of(swim.series);
      final edited = applyEdit(
        calendar,
        ChangeSeries(
          'swim@example.com',
          EventDraft(
            summary: 'Swimming club',
            start: draft.start,
            end: draft.end,
            description: draft.description,
            repeat: draft.repeat,
          ),
          from: draft,
          at: _at,
        ),
      );
      final before = calendar.text.split('\n');
      final after = edited.text.split('\n');
      expect(
        after,
        containsAll(['SUMMARY:Swimming club', 'X-EXAMPLE-COLOR:blue']),
      );
      expect(after, contains(' ip card at the desk'), reason: 'still folded');
      expect(after, contains('SEQUENCE:1'));
      expect(
        edited.unitOf(const UidKey.event('dentist@example.com'))!.text,
        calendar.unitOf(const UidKey.event('dentist@example.com'))!.text,
      );
      expect(
        after.where((line) => line.startsWith('BEGIN:VTODO')),
        hasLength(1),
      );
      expect(after.length, before.length);
      expect(
        edited.eventOf('swim@example.com')!.changed.single.summary,
        'Swimming (late)',
      );
    },
  );

  test('an edit that changes nothing changes no text', () {
    final calendar = Calendar.read(birthday)!;
    final ann = calendar.eventOf('ann@truce')!;
    final edited = applyEdit(
      calendar,
      ChangeSeries(
        'ann@truce',
        EventDraft.of(ann.series),
        from: EventDraft.of(ann.series),
        at: _at,
      ),
    );
    final added = edited.text
        .split('\n')
        .toSet()
        .difference(calendar.text.split('\n').toSet());
    expect(added, {
      'LAST-MODIFIED:20261101T120000Z',
      'SEQUENCE:1',
      'DTSTAMP:20261101T120000Z',
    }, reason: 'only the stamps');
  });

  test(
    'an edit writes its event and the block of a new zone, nothing else',
    () {
      final calendar = Calendar.read(birthday)!;
      final call = AddEvent(
        'call@t',
        EventDraft(
          summary: 'Call',
          start: Zoned('Asia/Tokyo', DateTime(2026, 11, 3, 9)),
          end: Zoned('Asia/Tokyo', DateTime(2026, 11, 3, 10)),
        ),
        at: _at,
      );
      expect(writeEdit(calendar, call).written, [
        UidKey.event('call@t'),
        const ZoneKey('Asia/Tokyo'),
      ]);
      expect(
        writeEdit(calendar, DeleteEvent('none@t', at: _at)).written,
        isEmpty,
        reason: 'no such event',
      );
    },
  );

  test('a deleted event stays as a marker', () {
    final calendar = _edited(birthday, DeleteEvent('ann@truce', at: _at));
    final marker = calendar.eventOf('ann@truce')!.series;
    expect(
      (marker.deleted, marker.cancelled, marker.summary),
      (true, true, 'Ann'),
    );
    expect(marker.component.value('RRULE'), isNull);
    expect(occurrences(calendar, DateTime(2020), DateTime(2030)), isEmpty);
  });

  group('a form saved after the event changed elsewhere', () {
    // The form opened on Ann's birthday; then another device renamed it.
    final elsewhere = _edited(
      birthday,
      ChangeSeries(
        'ann@truce',
        EventDraft(
          summary: 'Ann (elsewhere)',
          start: annDraft.start,
          end: annDraft.end,
          repeat: annDraft.repeat,
        ),
        from: annDraft,
        at: _at,
      ),
    );
    final moved = EventDraft(
      summary: annDraft.summary,
      start: AllDay(DateTime(2020, 3, 14)),
      end: AllDay(DateTime(2020, 3, 15)),
      repeat: annDraft.repeat,
    );

    test("keeps that change where the user didn't change the field", () {
      final event = applyEdit(
        elsewhere,
        ChangeSeries('ann@truce', moved, from: annDraft, at: _at),
      ).eventOf('ann@truce')!;
      expect(event.series.summary, 'Ann (elsewhere)');
      expect(event.series.start, AllDay(DateTime(2020, 3, 14)));
    });

    test('of one occurrence, the same', () {
      final one = AllDay(DateTime(2027, 3, 12));
      final from = EventDraft.at(
        Calendar.read(birthday)!.eventOf('ann@truce')!,
        one,
      );
      final event = applyEdit(
        elsewhere,
        ChangeOccurrence(
          'ann@truce',
          one,
          from.occurrenceAt(
            AllDay(DateTime(2027, 3, 14)),
            AllDay(DateTime(2027, 3, 15)),
          ),
          from: from,
          at: _at,
        ),
      ).eventOf('ann@truce')!;
      final changed = event.changed.single;
      expect(changed.summary, 'Ann (elsewhere)');
      expect(changed.start, AllDay(DateTime(2027, 3, 14)));
    });

    test('writes what the user changed over the change elsewhere', () {
      final renamed = EventDraft(
        summary: 'Ann!',
        start: annDraft.start,
        end: annDraft.end,
        repeat: annDraft.repeat,
      );
      final event = applyEdit(
        elsewhere,
        ChangeSeries('ann@truce', renamed, from: annDraft, at: _at),
      ).eventOf('ann@truce')!;
      expect(event.series.summary, 'Ann!');
    });
  });

  test('one occurrence changed becomes a changed occurrence of the series', () {
    final calendar = _edited(
      birthday,
      ChangeOccurrence(
        'ann@truce',
        AllDay(DateTime(2027, 3, 12)),
        EventDraft(
          summary: 'Ann (party)',
          start: AllDay(DateTime(2027, 3, 13)),
          end: AllDay(DateTime(2027, 3, 14)),
        ),
        from: EventDraft.at(
          Calendar.read(birthday)!.eventOf('ann@truce')!,
          AllDay(DateTime(2027, 3, 12)),
        ),
        at: _at,
      ),
    );
    final event = calendar.eventOf('ann@truce')!;
    expect(event.series.summary, 'Ann');
    final changed = event.changed.single;
    expect(changed.recurrenceId, AllDay(DateTime(2027, 3, 12)));
    expect(changed.repeat, isNull);
    final shown = occurrences(calendar, DateTime(2027), DateTime(2028));
    expect(shown.single.part.summary, 'Ann (party)');
    expect(shown.single.start, DateTime(2027, 3, 13));
  });

  test('a draft for one occurrence keeps all but the repeat', () {
    final series = EventDraft.of(
      Calendar.read(birthday)!.eventOf('ann@truce')!.series,
    );
    final one = series.occurrenceAt(
      AllDay(DateTime(2027, 3, 12)),
      AllDay(DateTime(2027, 3, 13)),
    );
    expect(series.repeat, isNotNull);
    expect(one.repeat, isNull);
    expect(one.summary, 'Ann');
    expect(one.start, AllDay(DateTime(2027, 3, 12)));
    expect(one.end, AllDay(DateTime(2027, 3, 13)));
  });

  test('one occurrence deleted is left out of its series', () {
    final calendar = _edited(
      birthday,
      DeleteOccurrence('ann@truce', AllDay(DateTime(2027, 3, 12)), at: _at),
    );
    expect(occurrences(calendar, DateTime(2027), DateTime(2028)), isEmpty);
    expect(occurrences(calendar, DateTime(2028), DateTime(2029)), hasLength(1));
    expect(calendar.text, contains('EXDATE;VALUE=DATE:20270312\n'));
  });

  test('a health entry is a tagged all-day event with its values', () {
    final calendar = _edited(
      newCalendarText('Me', health: true),
      AddEvent(
        'p1@truce',
        EventDraft.health(
          const Period(PeriodFlow.heavy),
          DateTime.utc(2026, 11, 1),
        ),
        at: _at,
      ),
    );
    final part = calendar.eventOf('p1@truce')!.series;
    expect(part.health, const Period(PeriodFlow.heavy));
    expect(part.summary, 'Period: heavy');
    expect(part.allDay, isTrue);
    expect(calendar.text, contains('CATEGORIES:HEALTH,PERIOD\n'));
    expect(calendar.text, contains('X-TRUCE-FLOW:heavy\n'));
  });

  test('alerts are written as display alarms before the start', () {
    final calendar = _edited(
      birthday,
      AddEvent(
        'a@truce',
        EventDraft(
          summary: 'Call',
          start: Floating(DateTime(2026, 11, 3, 18)),
          end: Floating(DateTime(2026, 11, 3, 19)),
          alerts: const [Duration(minutes: 15)],
        ),
        at: _at,
      ),
    );
    expect(calendar.text, contains('TRIGGER:-PT15M\n'));
    expect(calendar.eventOf('a@truce')!.series.alerts, [
      const Duration(minutes: 15),
    ]);
  });

  test('a new start of an event with a duration keeps its end', () {
    const text =
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:d@x\nDTSTART:20261103T180000\n'
        'DURATION:PT2H\nSUMMARY:Talk\nEND:VEVENT\nEND:VCALENDAR\n';
    final part = Calendar.read(text)!.eventOf('d@x')!.series;
    final draft = EventDraft.of(part);
    final edited = _edited(
      text,
      ChangeSeries(
        'd@x',
        EventDraft(
          summary: draft.summary,
          start: Floating(DateTime(2026, 11, 3, 17)),
          end: draft.end,
        ),
        from: draft,
        at: _at,
      ),
    );
    final moved = edited.eventOf('d@x')!.series;
    expect(moved.end, Floating(DateTime(2026, 11, 3, 20)));
    expect(edited.text, isNot(contains('DURATION')));
  });

  test("a health edit keeps the event's other categories", () {
    const text =
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:h@x\n'
        'DTSTART;VALUE=DATE:20261101\nSUMMARY:Period: light\n'
        'CATEGORIES:HEALTH,PERIOD,PRIVATE\nX-TRUCE-FLOW:light\n'
        'END:VEVENT\nEND:VCALENDAR\n';
    final edited = _edited(
      text,
      ChangeSeries(
        'h@x',
        EventDraft.health(
          const Period(PeriodFlow.heavy),
          DateTime(2026, 11, 1),
        ),
        from: EventDraft.health(
          const Period(PeriodFlow.light),
          DateTime(2026, 11, 1),
        ),
        at: _at,
      ),
    );
    expect(edited.text, contains('CATEGORIES:PRIVATE\n'));
    expect(edited.text, contains('CATEGORIES:HEALTH,PERIOD\n'));
    expect(
      edited.eventOf('h@x')!.series.health,
      const Period(PeriodFlow.heavy),
    );
  });

  test('an alert edit keeps the alarms the form does not show', () {
    const text =
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:a@x\nDTSTART:20261103T180000\n'
        'DTEND:20261103T190000\nSUMMARY:Call\n'
        'BEGIN:VALARM\nACTION:DISPLAY\nTRIGGER:-PT10M\nEND:VALARM\n'
        'BEGIN:VALARM\nACTION:AUDIO\nTRIGGER:-PT5M\nEND:VALARM\n'
        'BEGIN:VALARM\nACTION:DISPLAY\nTRIGGER;VALUE=DATE-TIME:20261103T090000Z\n'
        'END:VALARM\nEND:VEVENT\nEND:VCALENDAR\n';
    final part = Calendar.read(text)!.eventOf('a@x')!.series;
    expect(part.alerts, [const Duration(minutes: 10)]);
    final draft = EventDraft.of(part);
    final edited = _edited(
      text,
      ChangeSeries(
        'a@x',
        EventDraft(
          summary: draft.summary,
          start: draft.start,
          end: draft.end,
          alerts: const [Duration(minutes: 30)],
        ),
        from: draft,
        at: _at,
      ),
    );
    expect(edited.text, contains('ACTION:AUDIO\n'));
    expect(edited.text, contains('TRIGGER;VALUE=DATE-TIME:20261103T090000Z\n'));
    expect(edited.text, contains('TRIGGER:-PT30M\n'));
    expect(edited.text, isNot(contains('TRIGGER:-PT10M')));
  });

  test('long lines are folded at 75 octets, never inside a character', () {
    final summary = 'Ü' * 60;
    final calendar = _edited(
      birthday,
      AddEvent('f@truce', _draft(summary, DateTime(2026, 11, 3)), at: _at),
    );
    final lines = calendar.text.split('\n');
    expect(lines.every((line) => utf8.encode(line).length <= 75), isTrue);
    expect(
      Calendar.read(calendar.text)!.eventOf('f@truce')!.series.summary,
      summary,
    );
  });

  group('an event color', () {
    final colored = birthday.replaceFirst(
      'SUMMARY:Ann\n',
      'SUMMARY:Ann\nCOLOR:Turquoise\n',
    );

    test('is read as written, with its RGB', () {
      final ann = Calendar.read(colored)!.eventOf('ann@truce')!.series;
      expect(ann.color?.value, 'Turquoise');
      expect(ann.color?.rgb, 0x40E0D0);
      expect(const EventColor('#0a0').rgb, 0x00AA00);
      expect(const EventColor('#123456').rgb, 0x123456);
      expect(const EventColor('no color').rgb, isNull);
    });

    test('an unknown color stays byte for byte when the form changes '
        'something else', () {
      final odd = birthday.replaceFirst(
        'SUMMARY:Ann\n',
        'SUMMARY:Ann\nCOLOR;X-A=1:wat\n',
      );
      final from = EventDraft.of(
        Calendar.read(odd)!.eventOf('ann@truce')!.series,
      );
      final renamed = EventDraft(
        summary: 'Ann!',
        start: from.start,
        end: from.end,
        repeat: from.repeat,
        color: from.color,
      );
      final edited = _edited(
        odd,
        ChangeSeries('ann@truce', renamed, from: from, at: _at),
      );
      expect(edited.text, contains('COLOR;X-A=1:wat\n'));
    });

    test('is set, and removed only when the user picks none', () {
      final from = EventDraft.of(
        Calendar.read(birthday)!.eventOf('ann@truce')!.series,
      );
      EventDraft withColor(EventColor? color) => EventDraft(
        summary: from.summary,
        start: from.start,
        end: from.end,
        repeat: from.repeat,
        color: color,
      );
      final set = _edited(
        birthday,
        ChangeSeries(
          'ann@truce',
          withColor(const EventColor('teal')),
          from: from,
          at: _at,
        ),
      );
      expect(set.text, contains('COLOR:teal\n'));
      final setFrom = EventDraft.of(set.eventOf('ann@truce')!.series);
      final removed = applyEdit(
        set,
        ChangeSeries('ann@truce', withColor(null), from: setFrom, at: _at),
      );
      expect(removed.text, isNot(contains('COLOR')));
    });

    test('changed elsewhere while the form is open is kept', () {
      final from = EventDraft.of(
        Calendar.read(birthday)!.eventOf('ann@truce')!.series,
      );
      final renamed = EventDraft(
        summary: 'Ann!',
        start: from.start,
        end: from.end,
        repeat: from.repeat,
      );
      final edited = _edited(
        colored,
        ChangeSeries('ann@truce', renamed, from: from, at: _at),
      ).eventOf('ann@truce')!.series;
      expect((edited.summary, edited.color?.value), ('Ann!', 'Turquoise'));
    });
  });

  test('a new event gets a random uid of its own', () {
    final [one, other] = [newUid(), newUid()];
    expect(one, matches(RegExp(r'^[0-9a-f]{32}@truce$')));
    expect(one, isNot(other));
  });
}

void _repeatEnds() {
  Calendar series(String rule) => Calendar.read(
    'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:s\nDTSTART;VALUE=DATE:20261102\n'
    'DTEND;VALUE=DATE:20261103\nRRULE:$rule\nSUMMARY:Run\nEND:VEVENT\n'
    'END:VCALENDAR\n',
  )!;

  /// The rule of series `s` after its start becomes 9:00 in Berlin.
  String timedRule(Calendar calendar) {
    final draft = EventDraft.of(calendar.eventOf('s')!.series);
    final edited = applyEdit(
      calendar,
      ChangeSeries(
        's',
        EventDraft(
          summary: draft.summary,
          start: Zoned('Europe/Berlin', DateTime.utc(2026, 11, 2, 9)),
          end: Zoned('Europe/Berlin', DateTime.utc(2026, 11, 2, 10)),
          repeat: draft.repeat,
        ),
        from: draft,
        at: _at,
      ),
    );
    return edited.eventOf('s')!.series.rule!;
  }

  test('a new start writes the repeat\'s last day as the start does', () {
    expect(
      timedRule(series('FREQ=DAILY;UNTIL=20261110')),
      'FREQ=DAILY;UNTIL=20261110T225959Z',
    );
  });

  test('a rule the form does not edit keeps all but its last day', () {
    expect(
      timedRule(series('FREQ=MONTHLY;BYDAY=2TU;UNTIL=20271110')),
      'FREQ=MONTHLY;BYDAY=2TU;UNTIL=20271110T225959Z',
    );
  });

  test('a rule stays as written when the start stays', () {
    final calendar = series('FREQ=DAILY;INTERVAL=1;UNTIL=20261110');
    final draft = EventDraft.of(calendar.eventOf('s')!.series);
    final edited = applyEdit(
      calendar,
      ChangeSeries(
        's',
        EventDraft(
          summary: 'Long run',
          start: draft.start,
          end: draft.end,
          repeat: draft.repeat,
        ),
        from: draft,
        at: _at,
      ),
    );
    expect(
      edited.eventOf('s')!.series.rule,
      'FREQ=DAILY;INTERVAL=1;UNTIL=20261110',
    );
  });
}

/// A daily series at 9:00 from Monday 2 November 2026, with
/// [lines] added (e.g. a left-out date), and a changed occurrence when
/// [changed] is given (its `RECURRENCE-ID` and start).
String _daily({
  String lines = '',
  String rule = 'FREQ=DAILY',
  String? changed,
}) =>
    'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:s@x\nDTSTART:20261102T090000\n'
    'DTEND:20261102T100000\nRRULE:$rule\n${lines}SUMMARY:Run\nEND:VEVENT\n'
    '${changed ?? ''}END:VCALENDAR\n';

/// [text]'s series `s@x` moved to start at [start] (an hour long).
Calendar _movedTo(String text, CalendarTime start) {
  final draft = EventDraft.of(Calendar.read(text)!.eventOf('s@x')!.series);
  return _edited(
    text,
    ChangeSeries(
      's@x',
      EventDraft(
        summary: draft.summary,
        start: start,
        end: start.at(start.wall.add(const Duration(hours: 1))),
        repeat: draft.repeat,
      ),
      from: draft,
      at: _at,
    ),
  );
}

/// The summaries of [calendar]'s occurrences from [from] for [days] days.
List<(DateTime, String)> _shown(Calendar calendar, DateTime from, int days) => [
  for (final occurrence in occurrences(
    calendar,
    from,
    from.add(Duration(days: days)),
  ))
    (occurrence.start, occurrence.part.summary),
];

void _startMoves() {
  test('a left-out date and a changed one move with their slots', () {
    final text = _daily(
      lines: 'EXDATE:20261104T090000\n',
      changed:
          'BEGIN:VEVENT\nUID:s@x\nRECURRENCE-ID:20261105T090000\n'
          'DTSTART:20261105T070000\nDTEND:20261105T080000\n'
          'SUMMARY:Early run\nEND:VEVENT\n',
    );
    final moved = _movedTo(text, Floating(DateTime(2026, 11, 3, 10)));

    expect(moved.text, contains('EXDATE:20261105T100000\n'));
    expect(moved.text, contains('RECURRENCE-ID:20261106T100000\n'));
    expect(
      moved.text,
      contains('DTSTART:20261105T070000\n'),
      reason: 'a changed one keeps its own times',
    );
    expect(_shown(moved, DateTime(2026, 11, 3), 5), [
      (DateTime(2026, 11, 3, 10), 'Run'),
      (DateTime(2026, 11, 4, 10), 'Run'),
      (DateTime(2026, 11, 5, 7), 'Early run'),
      (DateTime(2026, 11, 7, 10), 'Run'),
    ], reason: 'the 5th left out, the 6th changed; nothing shows twice');
  });

  test('a repeat on fixed days keeps their dates; only the time moves', () {
    final text = _daily(
      rule: 'FREQ=WEEKLY;BYDAY=MO',
      lines: 'EXDATE:20261109T090000\n',
    );
    final moved = _movedTo(text, Floating(DateTime(2026, 11, 3, 10)));

    expect(moved.text, contains('EXDATE:20261109T100000\n'));
  });

  test('a series turned from days into times moves its slots to times', () {
    const text =
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:s@x\n'
        'DTSTART;VALUE=DATE:20261102\nDTEND;VALUE=DATE:20261103\n'
        'RRULE:FREQ=DAILY\nEXDATE;VALUE=DATE:20261104,20261106\n'
        'SUMMARY:Run\nEND:VEVENT\nEND:VCALENDAR\n';
    final moved = _movedTo(
      text,
      Zoned('Europe/Berlin', DateTime.utc(2026, 11, 2, 9)),
    );

    expect(
      moved.text,
      contains('EXDATE;TZID=Europe/Berlin:20261104T090000,20261106T090000\n'),
    );
  });

  test('an unchanged start leaves the slots as written', () {
    final text = _daily(lines: 'EXDATE:20261104T090000\n');
    final draft = EventDraft.of(Calendar.read(text)!.eventOf('s@x')!.series);
    final edited = _edited(
      text,
      ChangeSeries(
        's@x',
        EventDraft(
          summary: 'Long run',
          start: draft.start,
          end: draft.end,
          repeat: draft.repeat,
        ),
        from: draft,
        at: _at,
      ),
    );

    expect(edited.text, contains('EXDATE:20261104T090000\n'));
  });

  test('a series of extra dates alone moves its slots too', () {
    final text = _daily(
      rule: 'X',
      lines: 'RDATE:20261104T090000,20261106T090000\nEXDATE:20261104T090000\n',
    ).replaceFirst('RRULE:X\n', '');
    final moved = _movedTo(text, Floating(DateTime(2026, 11, 2, 10)));

    expect(moved.text, contains('EXDATE:20261104T100000\n'));
  });

  test('a repeat turned off leaves a single event: its left-out, extra and '
      'changed dates go', () {
    final text = _daily(
      lines: 'EXDATE:20261104T090000\nRDATE:20261120T090000\n',
      changed:
          'BEGIN:VEVENT\nUID:s@x\nRECURRENCE-ID:20261105T090000\n'
          'DTSTART:20261105T070000\nDTEND:20261105T080000\n'
          'SUMMARY:Early run\nEND:VEVENT\n',
    );
    final draft = EventDraft.of(Calendar.read(text)!.eventOf('s@x')!.series);
    final edited = _edited(
      text,
      ChangeSeries(
        's@x',
        EventDraft(summary: 'Run', start: draft.start, end: draft.end),
        from: draft,
        at: _at,
      ),
    );

    final unit = edited.unitOf(const UidKey.event('s@x'))!.text;
    for (final gone in ['RRULE', 'EXDATE', 'RDATE', 'RECURRENCE-ID']) {
      expect(unit, isNot(contains(gone)));
    }
    expect(_shown(edited, DateTime(2026, 11), 30), [
      (DateTime(2026, 11, 2, 9), 'Run'),
    ]);
  });
}

void _extraDatesOnly() {
  test('one of a series of extra dates alone deleted leaves out that one', () {
    const text =
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:r@x\nDTSTART:20261102T090000\n'
        'DTEND:20261102T100000\nRDATE:20261104T090000\nSUMMARY:Class\n'
        'END:VEVENT\nEND:VCALENDAR\n';
    final edited = _edited(
      text,
      DeleteOccurrence('r@x', Floating(DateTime.utc(2026, 11, 4, 9)), at: _at),
    );

    expect(edited.text, contains('EXDATE:20261104T090000\n'));
    expect(_shown(edited, DateTime(2026, 11), 30), [
      (DateTime(2026, 11, 2, 9), 'Class'),
    ]);
  });
}
