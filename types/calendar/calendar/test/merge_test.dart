import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';

import 'samples.dart';

const _merge = CalendarMerge();

String _apply(String text, List<CalendarEdit> edits) =>
    edits.fold(Calendar.read(text)!, applyEdit).text;

EventDraft _draft(String summary, DateTime start) => EventDraft(
  summary: summary,
  start: Floating(start),
  end: Floating(start.add(const Duration(hours: 1))),
);

String _merged(String main, String other, {String? base}) =>
    (_merge.merge(main, other, base: base) as MergedText).text;

void main() {
  final day1 = DateTime.utc(2026, 11, 1, 10);
  final day2 = DateTime.utc(2026, 11, 2, 10);

  // Two devices from one text: one adds an event, the other edits Ann.
  final added = _apply(birthday, [
    AddEvent('gym@a', _draft('Gym', DateTime(2026, 11, 3, 18)), at: day1),
  ]);
  final renamed = _apply(birthday, [
    ChangeSeries(
      'ann@truce',
      EventDraft(
        summary: 'Ann (birthday)',
        start: AllDay(DateTime(2020, 3, 12)),
        end: AllDay(DateTime(2020, 3, 13)),
        repeat: const SimpleRepeat(Frequency.yearly),
      ),
      from: annDraft,
      at: day2,
    ),
  ]);

  test('keeps what each side added and the newer edit of each event', () {
    final calendar = Calendar.read(_merged(added, renamed))!;
    expect(calendar.eventOf('gym@a')!.series.summary, 'Gym');
    expect(calendar.eventOf('ann@truce')!.series.summary, 'Ann (birthday)');
  });

  test('is the same either way round, but for the order of new units', () {
    final ab = Calendar.read(_merged(added, renamed))!;
    final ba = Calendar.read(_merged(renamed, added))!;
    expect(
      {for (final unit in ab.units) unit.key: unit.text},
      {for (final unit in ba.units) unit.key: unit.text},
    );
  });

  test('is idempotent and deterministic', () {
    final once = _merged(added, renamed);
    expect(_merged(once, renamed), once);
    expect(_merged(once, added), once);
    expect(_merged(once, once), once);
    expect(_merged(added, renamed), once);
  });

  test('keeps the layout of main: parts of one event that lie apart', () {
    expect(_merged(exported, exported), exported);
    final renamed = _apply(exported, [
      DeleteEvent('dentist@example.com', at: day2),
    ]);
    expect(_merged(exported, renamed), _merged(renamed, renamed));
  });

  test("never changes a unit's text: each is one side's", () {
    final inputs = {
      for (final text in [added, renamed])
        for (final unit in Calendar.read(text)!.units) unit.text,
    };
    for (final unit in Calendar.read(_merged(added, renamed))!.units) {
      expect(inputs, contains(unit.text));
    }
  });

  test('a delete wins over an older edit, and stays a marker', () {
    final deleted = _apply(birthday, [DeleteEvent('ann@truce', at: day2)]);
    final edited = _apply(birthday, [
      ChangeSeries(
        'ann@truce',
        EventDraft(
          summary: 'Ann!',
          start: AllDay(DateTime(2020, 3, 12)),
          end: AllDay(DateTime(2020, 3, 13)),
        ),
        from: annDraft,
        at: day1,
      ),
    ]);
    final calendar = Calendar.read(_merged(edited, deleted))!;
    expect(calendar.eventOf('ann@truce')!.series.deleted, isTrue);
  });

  test("names the other side's edits that lost, changed from the base", () {
    final older = _apply(birthday, [
      ChangeSeries(
        'ann@truce',
        EventDraft(
          summary: 'Ann (older)',
          start: AllDay(DateTime(2020, 3, 12)),
          end: AllDay(DateTime(2020, 3, 13)),
        ),
        from: annDraft,
        at: day1,
      ),
    ]);
    final result = _merge.merge(renamed, older, base: birthday) as MergedText;
    expect(result.lost, ['Ann (older)']);
    // The base itself loses, but holds no edit of its own.
    final quiet = _merge.merge(renamed, birthday, base: birthday) as MergedText;
    expect(quiet.lost, isEmpty);
  });

  test("names the main side's version too when the other's is newer", () {
    final older = _apply(birthday, [
      ChangeSeries(
        'ann@truce',
        EventDraft(
          summary: 'Ann (older)',
          start: AllDay(DateTime(2020, 3, 12)),
          end: AllDay(DateTime(2020, 3, 13)),
        ),
        from: annDraft,
        at: day1,
      ),
    ]);
    final result = _merge.merge(older, renamed) as MergedText;
    expect(result.lost, ['Ann (older)']);
  });

  test('without stamps, the smaller text wins on every device', () {
    const a =
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\nSUMMARY:A\nEND:VEVENT\nEND:VCALENDAR\n';
    const b =
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\nSUMMARY:B\nEND:VEVENT\nEND:VCALENDAR\n';
    expect(_merged(a, b), a);
    expect(_merged(b, a), a);
  });

  group('with the base both came from', () {
    // Same stamps; the base's text is the smaller one.
    final base = _calendarWith('VEVENT', 'A');
    final edited = _calendarWith('VEVENT', 'B');

    test("keeps the one side's change, even without new stamps", () {
      for (final (main, other) in [(base, edited), (edited, base)]) {
        final result = _merge.merge(main, other, base: base) as MergedText;
        expect(result.text, edited);
        expect(result.lost, isEmpty);
      }
    });

    test('takes the newer edit where both sides changed a unit', () {
      final older = _apply(birthday, [
        ChangeSeries(
          'ann@truce',
          EventDraft(
            summary: 'Ann (older)',
            start: AllDay(DateTime(2020, 3, 12)),
            end: AllDay(DateTime(2020, 3, 13)),
          ),
          from: annDraft,
          at: day1,
        ),
      ]);
      final calendar = Calendar.read(_merged(older, renamed, base: birthday))!;
      expect(calendar.eventOf('ann@truce')!.series.summary, 'Ann (birthday)');
    });

    test('merges a task one side changed into one copy of it', () {
      final (base, edited) = (
        _calendarWith('VTODO', 'Buy paint'),
        _calendarWith('VTODO', 'Buy blue paint'),
      );
      final result = _merge.merge(base, edited, base: base) as MergedText;
      expect(result.text, edited);
      expect(result.lost, isEmpty);
    });
  });

  test('without edit stamps, the later DTSTAMP wins; an edit stamp beats '
      'any DTSTAMP', () {
    String event(String summary, String lines) =>
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\n$lines'
        'SUMMARY:$summary\nEND:VEVENT\nEND:VCALENDAR\n';
    final first = event('Zoo trip', 'DTSTAMP:20270101T080000Z\n');
    final corrected = event('Aquarium trip', 'DTSTAMP:20270102T080000Z\n');
    expect(_merged(first, corrected), corrected);
    expect(_merged(corrected, first), corrected);

    final edited = event(
      'Zoo trip',
      'DTSTAMP:20261201T080000Z\nLAST-MODIFIED:20261201T080000Z\n',
    );
    expect(_merged(corrected, edited), edited);
  });

  test('versions that differ only in their stamps lose nothing', () {
    String event(String stamp) =>
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\nDTSTAMP:$stamp\n'
        'LAST-MODIFIED:$stamp\nSEQUENCE:1\nSUMMARY:Kite day\n'
        'END:VEVENT\nEND:VCALENDAR\n';
    final result = _merge.merge(
      event('20270101T080000Z'),
      event('20270102T080000Z'),
    ) as MergedText;
    expect(result.lost, isEmpty);
  });

  test('without a base, a task changed on both sides is kept once', () {
    final older = _calendarWith('VTODO', 'Buy paint');
    final newer = _calendarWith(
      'VTODO',
      'Buy blue paint',
      modified: '20261002T080000Z',
    );
    final result = _merge.merge(older, newer) as MergedText;
    expect(result.text, newer);
    expect(result.lost, ['Buy paint']);
  });

  test('keeps a task and an event with the same UID apart', () {
    const both =
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\nSUMMARY:Meet\nEND:VEVENT\n'
        'BEGIN:VTODO\nUID:x\nSUMMARY:Prepare\nEND:VTODO\nEND:VCALENDAR\n';
    final calendar = Calendar.read(both)!;
    expect(calendar.units, hasLength(2));
    expect(calendar.eventOf('x')!.series.summary, 'Meet');
    expect(_merged(both, both), both);
  });

  test('a text that is no calendar does not merge', () {
    expect(_merge.merge(birthday, '# Notes\n'), isA<CantMerge>());
    expect(_merge.merge('', birthday), isA<CantMerge>());
  });

  test('keeps the time zones and other components of both sides', () {
    final merged = Calendar.read(_merged(exported, birthday))!;
    expect(merged.text, contains('BEGIN:VTIMEZONE'));
    expect(merged.text, contains('BEGIN:VTODO'));
    expect(merged.eventOf('ann@truce'), isNotNull);
    expect(merged.name, 'Family', reason: "main's own properties");
  });

  test("the name takes the other side's rename where only it renamed", () {
    final named = Calendar.read(birthday)!.named('Family').text;
    expect(
      Calendar.read(_merged(added, named, base: birthday))!.name,
      'Family',
    );
    expect(
      Calendar.read(_merged(named, added, base: birthday))!.name,
      'Family',
    );
    expect(
      Calendar.read(_merged(added, named))!.name,
      'Birthdays',
      reason: "without a base, main's",
    );
  });

  test("a name both renamed is main's, and the other's is lost", () {
    final ours = Calendar.read(birthday)!.named('Ours').text;
    final theirs = Calendar.read(birthday)!.named('Theirs').text;
    final merged = _merge.merge(ours, theirs, base: birthday) as MergedText;
    expect(Calendar.read(merged.text)!.name, 'Ours');
    expect(merged.lost, contains('Calendar name'));
  });

  test('an empty name kept out by a merge is not told as lost', () {
    final named = Calendar.read(birthday)!.named('Family').text;
    final unnamed = Calendar.read(birthday)!.named('').text;
    final merged = _merge.merge(named, unnamed) as MergedText;
    expect(Calendar.read(merged.text)!.name, 'Family');
    expect(merged.lost, isNot(contains('Calendar name')));
  });
}

/// A calendar of one [component] with `UID:x`.
String _calendarWith(
  String component,
  String summary, {
  String modified = '20261001T080000Z',
}) =>
    'BEGIN:VCALENDAR\nBEGIN:$component\nUID:x\nLAST-MODIFIED:$modified\n'
    'SUMMARY:$summary\nEND:$component\nEND:VCALENDAR\n';
