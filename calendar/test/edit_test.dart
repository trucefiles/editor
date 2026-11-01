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
  test('a new event is added at the end, stamped, floating', () {
    final calendar = _edited(
      birthday,
      AddEvent('new@truce', _draft('Gym', DateTime(2026, 11, 3, 18)), at: _at),
    );
    final unit = calendar.unitOf(const UidKey('new@truce'))!.text;
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
        edited.unitOf(const UidKey('dentist@example.com'))!.text,
        calendar.unitOf(const UidKey('dentist@example.com'))!.text,
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
      ChangeSeries('ann@truce', EventDraft.of(ann.series), at: _at),
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
}
