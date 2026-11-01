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
        at: day1,
      ),
    ]);
    final result = _merge.merge(renamed, older, base: birthday) as MergedText;
    expect(result.lost, ['Ann (older)']);
    // The base itself loses, but holds no edit of its own.
    final quiet = _merge.merge(renamed, birthday, base: birthday) as MergedText;
    expect(quiet.lost, isEmpty);
  });

  test('without stamps, the smaller text wins on every device', () {
    const a =
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\nSUMMARY:A\nEND:VEVENT\nEND:VCALENDAR\n';
    const b =
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\nSUMMARY:B\nEND:VEVENT\nEND:VCALENDAR\n';
    expect(_merged(a, b), a);
    expect(_merged(b, a), a);
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
}
