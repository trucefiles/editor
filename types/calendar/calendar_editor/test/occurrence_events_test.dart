import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/views/occurrence_event.dart';
import 'package:truce_calendar_editor/src/views/occurrence_events.dart';

/// A calendar with one event [summary] from [start] to [end] (written as
/// `.ics` times on the device clock).
Calendar _with(String summary, String start, String end) => Calendar.read(
  'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:$summary\n'
  'DTSTART:$start\nDTEND:$end\nSUMMARY:$summary\nEND:VEVENT\n'
  'END:VCALENDAR\n',
)!;

/// What kalender gets for [from] to [to]: each event's calendar and
/// summary.
List<(String, String)> _ask(
  OccurrenceEvents<String> events,
  DateTime from,
  DateTime to,
) => [
  for (final event in events.eventsInRange(
    FloatingDateTimeRange(start: from, end: to),
    multiDayRule: const MultiDayRule.calendarDays(),
  ))
    switch (event) {
      OccurrenceEvent<String>(:final calendar, :final occurrence) => (
        calendar,
        occurrence.part.summary,
      ),
      _ => throw StateError('not an occurrence'),
    },
];

void main() {
  final dentist = _with('Dentist', '20261105T090000', '20261105T100000');
  final review = _with('Review', '20261120T140000', '20261120T150000');

  test('answers each range from the months it touches, worked out once, '
      'and tells no one', () {
    final events = OccurrenceEvents({'home': dentist, 'work': review});
    addTearDown(events.dispose);
    var told = 0;
    events.addListener(() => told++);

    expect(_ask(events, DateTime(2026, 11, 2), DateTime(2026, 11, 9)), [
      ('home', 'Dentist'),
    ]);
    final november = events.events.toSet();
    expect(_ask(events, DateTime(2026, 11, 16), DateTime(2026, 11, 23)), [
      ('work', 'Review'),
    ]);
    expect(
      events.events.toSet(),
      november,
      reason: 'the month was worked out once: the same events, ids kept',
    );
    expect(_ask(events, DateTime(2027, 2), DateTime(2027, 3)), isEmpty);
    expect(told, 0);
  });

  test('an occurrence that spans months shows once in each, whichever '
      'month comes first', () {
    // From 30 January to 2 March: it touches three months.
    final trip = _with('Trip', '20270130T100000', '20270302T100000');
    final (january, february, march) = (
      (DateTime(2027), DateTime(2027, 2)),
      (DateTime(2027, 2), DateTime(2027, 3)),
      (DateTime(2027, 3), DateTime(2027, 4)),
    );
    for (final order in [
      [february, march, january],
      [march, january, february],
      [january, february, march],
    ]) {
      final events = OccurrenceEvents({'home': trip});
      addTearDown(events.dispose);
      for (final (from, to) in [...order, ...order]) {
        expect(_ask(events, from, to), [('home', 'Trip')]);
      }
      expect(events.events, hasLength(1), reason: 'held once');
    }
  });

  test('a changed calendar is worked out again; the others keep their '
      'events', () {
    final events = OccurrenceEvents({'home': dentist, 'work': review});
    addTearDown(events.dispose);
    final november = (DateTime(2026, 11), DateTime(2026, 12));
    _ask(events, november.$1, november.$2);
    final reviewEvent = events.events.firstWhere(
      (event) => (event as OccurrenceEvent<String>).calendar == 'work',
    );
    var told = 0;
    events.addListener(() => told++);

    events.showCalendars({'home': dentist.named('Family'), 'work': review});
    expect(told, 0, reason: 'renamed: the same days');

    final moved = _with('Dentist', '20261112T090000', '20261112T100000');
    events.showCalendars({'home': moved, 'work': review});
    expect(told, 1);
    expect(
      _ask(events, november.$1, november.$2),
      unorderedEquals([('home', 'Dentist'), ('work', 'Review')]),
    );
    expect(
      (events.eventsInRange(
        FloatingDateTimeRange(
          start: DateTime(2026, 11, 12),
          end: DateTime(2026, 11, 13),
        ),
        multiDayRule: const MultiDayRule.calendarDays(),
      )).single,
      isA<OccurrenceEvent<String>>(),
      reason: 'on its new day',
    );
    expect(events.byId(reviewEvent.id), same(reviewEvent));

    events.showCalendars({'work': review});
    expect(told, 2);
    expect(_ask(events, november.$1, november.$2), [('work', 'Review')]);
  });

  test('in another time zone, all is worked out again, each occurrence '
      'still once', () {
    var zone = 'here';
    final events = OccurrenceEvents({
      'home': dentist,
      'work': review,
    }, deviceZone: () => zone);
    addTearDown(events.dispose);
    final november = (DateTime(2026, 11), DateTime(2026, 12));
    _ask(events, november.$1, november.$2);
    final before = events.events.toSet();
    var told = 0;
    events.addListener(() => told++);

    zone = 'away';
    expect(
      _ask(events, november.$1, november.$2),
      unorderedEquals([('home', 'Dentist'), ('work', 'Review')]),
    );
    expect(events.events, hasLength(2));
    expect(events.events.toSet().intersection(before), isEmpty);
    expect(told, 0, reason: 'kalender asks again on its own');
  });
}
