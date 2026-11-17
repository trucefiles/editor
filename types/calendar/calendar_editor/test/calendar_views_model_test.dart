import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/views/calendar_views_model.dart';
import 'package:truce_calendar_editor/src/views_clock.dart';

/// A calendar named [name] with [event] on [day] from 9 to 10.
Calendar _calendar(String name, String event, DateTime day) => applyEdit(
  Calendar.read(newCalendarText(name))!,
  AddItem(
    event,
    EventDraft(
      summary: event,
      start: Floating(DateTime.utc(day.year, day.month, day.day, 9)),
      end: Floating(DateTime.utc(day.year, day.month, day.day, 10)),
    ),
    at: DateTime.utc(2026, 11),
  ),
);

/// A views clock on [now], disposed after the test, in the zone "UTC".
ViewsClock _clock(DateTime Function() now) {
  final clock = ViewsClock(now, deviceZone: () => 'UTC');
  addTearDown(clock.dispose);
  return clock;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final home = _calendar('Home', 'Dentist', DateTime(2026, 11, 5));
  final work = _calendar('Work', 'Review', DateTime(2026, 11, 20));

  test('a page change tells only the range', () {
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      clock: _clock(() => DateTime(2026, 11, 10, 12)),
    );
    addTearDown(model.dispose);
    final (changes, ranges) = (<String>[], <ShownRange?>[]);
    model.addListener(() => changes.add('model'));
    model.range.addListener(() => ranges.add(model.range.value));

    model
      ..showRange(DateTime(2026, 11), DateTime(2026, 12))
      ..showRange(DateTime(2026, 11), DateTime(2026, 12))
      ..showRange(DateTime(2026, 12), DateTime(2027));
    expect(changes, isEmpty);
    expect(ranges, [
      (from: DateTime(2026, 11), to: DateTime(2026, 12)),
      (from: DateTime(2026, 12), to: DateTime(2027)),
    ]);
  });

  test('other calendars are told; the same ones change nothing', () {
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      clock: _clock(() => DateTime(2026, 11, 10, 12)),
    );
    addTearDown(model.dispose);
    var changes = 0;
    model.addListener(() => changes++);

    model.showCalendars({'home': home});
    expect(changes, 0);

    model.showCalendars({'home': home, 'work': work});
    expect(changes, 1);
  });

  test('the view kind changes once', () {
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      clock: _clock(() => DateTime(2026, 11, 10, 12)),
    );
    addTearDown(model.dispose);
    var changes = 0;
    model.addListener(() => changes++);

    model
      ..showKind(CalendarViewKind.week)
      ..showKind(CalendarViewKind.week);
    expect((model.kind, changes), (CalendarViewKind.week, 1));
  });

  test('Add starts today if it shows, else on the first day shown', () {
    final model = CalendarViewsModel(
      kind: CalendarViewKind.week,
      calendars: {'home': home},
      clock: _clock(() => DateTime(2026, 11, 10, 12)),
    );
    addTearDown(model.dispose);

    model.showRange(DateTime(2026, 11), DateTime(2026, 12));
    expect(model.dayToAdd, DateTime(2026, 11, 10));
    model.showRange(DateTime(2026, 12), DateTime(2027));
    expect(model.dayToAdd, DateTime(2026, 12));
    model.showRange(DateTime(2026, 11, 3), DateTime(2026, 11, 10));
    expect(model.dayToAdd, DateTime(2026, 11, 3), reason: 'the end is out');
  });

  test("a month view's Add starts in its month, not in the weeks around "
      'it', () {
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      clock: _clock(() => DateTime(2026, 11, 30, 12)),
    );
    addTearDown(model.dispose);

    // December's grid starts on Sunday 29 November.
    model.showRange(DateTime(2026, 11, 29), DateTime(2027, 1, 10));
    expect(model.dayToAdd, DateTime(2026, 12));
    // November's grid ends on 5 December; today is in November.
    model.showRange(DateTime(2026, 11), DateTime(2026, 12, 6));
    expect(model.dayToAdd, DateTime(2026, 11, 30));
  });

  testWidgets('today moves on at midnight', (tester) async {
    var now = DateTime(2026, 11, 1, 23, 59);
    final clock = ViewsClock(() => now, deviceZone: () => 'UTC');
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      clock: clock,
    );
    var changes = 0;
    model.addListener(() => changes++);
    expect(model.today, DateTime(2026, 11));

    now = DateTime(2026, 11, 2);
    await tester.pump(const Duration(minutes: 1));

    expect((model.today, changes), (DateTime(2026, 11, 2), 1));
    // Ends the next wake before the test checks for timers.
    model.dispose();
    clock.dispose();
  });

  testWidgets('today moves on within a minute after a sleep past midnight', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 1, 22);
    final clock = ViewsClock(() => now, deviceZone: () => 'UTC');
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      clock: clock,
    );
    var changes = 0;
    model.addListener(() => changes++);

    await tester.pump(const Duration(minutes: 1));
    expect(changes, 0, reason: 'the same day');

    // The device slept: the clock went on, the timers didn't.
    now = DateTime(2026, 11, 2, 7);
    await tester.pump(const Duration(minutes: 1));

    expect((model.today, changes), (DateTime(2026, 11, 2), 1));
    model.dispose();
    clock.dispose();
  });

  test('a renamed calendar shows the same days: no change', () {
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      clock: _clock(() => DateTime(2026, 11, 10, 12)),
    );
    addTearDown(model.dispose);
    var changes = 0;
    model.addListener(() => changes++);

    model.showCalendars({'home': home.named('Family')});
    expect(changes, 0);
  });

  test('a box checked walks that task again; the others are kept', () {
    String task(String uid) =>
        'BEGIN:VTODO\nUID:$uid\nSUMMARY:$uid\n'
        'DUE;VALUE=DATE:20261120\nRRULE:FREQ=WEEKLY\nEND:VTODO\n';
    final home = Calendar.read(
      'BEGIN:VCALENDAR\nVERSION:2.0\n${task('water')}${task('bins')}'
      'END:VCALENDAR\n',
    )!;
    final model = CalendarViewsModel(
      kind: CalendarViewKind.tasks,
      calendars: {'home': home},
      clock: _clock(() => DateTime(2026, 11, 10, 12)),
    );
    addTearDown(model.dispose);
    TaskEntry entryOf(String uid) =>
        model.tasks.later.singleWhere((row) => row.entry.task.uid == uid).entry;
    final bins = entryOf('bins');

    model.showCalendars({
      'home': applyEdit(
        home,
        CheckTask(
          'water',
          AllDay(DateTime.utc(2026, 11, 20)),
          done: true,
          at: DateTime.utc(2026, 11, 10),
        ),
      ),
    });

    expect(identical(entryOf('bins'), bins), isTrue, reason: 'kept');
    expect(entryOf('water').date, AllDay(DateTime.utc(2026, 11, 27)));
  });
}
