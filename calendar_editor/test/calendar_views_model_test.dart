import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/views/calendar_views_model.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

/// A calendar named [name] with [event] on [day] from 9 to 10.
Calendar _calendar(String name, String event, DateTime day) => applyEdit(
  Calendar.read(newCalendarText(name))!,
  AddEvent(
    event,
    EventDraft(
      summary: event,
      start: Floating(DateTime.utc(day.year, day.month, day.day, 9)),
      end: Floating(DateTime.utc(day.year, day.month, day.day, 10)),
    ),
    at: DateTime.utc(2026, 11),
  ),
);

List<(String, String)> _shown(CalendarViewsModel<String> model) => [
  for (final (:calendar, :occurrence) in model.shown)
    (calendar, occurrence.part.summary),
];

void main() {
  final home = _calendar('Home', 'Dentist', DateTime(2026, 11, 5));
  final work = _calendar('Work', 'Review', DateTime(2026, 11, 20));

  test('shows the occurrences of its calendars in the range, by key', () {
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home, 'work': work},
      now: () => DateTime(2026, 11, 10, 12),
    );
    addTearDown(model.dispose);
    expect(model.shown, isEmpty, reason: 'no range yet');

    model.showRange(DateTime(2026, 11), DateTime(2026, 12));
    expect(_shown(model), [('home', 'Dentist'), ('work', 'Review')]);

    model.showRange(DateTime(2026, 11, 15), DateTime(2026, 11, 22));
    expect(_shown(model), [('work', 'Review')]);
  });

  test('new calendars show; the same ones change nothing', () {
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      now: () => DateTime(2026, 11, 10, 12),
    )..showRange(DateTime(2026, 11), DateTime(2026, 12));
    addTearDown(model.dispose);
    var changes = 0;
    model.addListener(() => changes++);

    model.showCalendars({'home': home});
    model.showRange(DateTime(2026, 11), DateTime(2026, 12));
    expect(changes, 0);

    model.showCalendars({'home': home, 'work': work});
    expect(changes, 1);
    expect(_shown(model), [('home', 'Dentist'), ('work', 'Review')]);
  });

  test('the view kind changes once', () {
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      now: () => DateTime(2026, 11, 10, 12),
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
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      now: () => DateTime(2026, 11, 10, 12),
    );
    addTearDown(model.dispose);

    model.showRange(DateTime(2026, 11), DateTime(2026, 12));
    expect(model.dayToAdd, DateTime(2026, 11, 10));
    model.showRange(DateTime(2026, 12), DateTime(2027));
    expect(model.dayToAdd, DateTime(2026, 12));
    model.showRange(DateTime(2026, 11, 3), DateTime(2026, 11, 10));
    expect(model.dayToAdd, DateTime(2026, 11, 3), reason: 'the end is out');
  });

  testWidgets('today moves on at midnight', (tester) async {
    var now = DateTime(2026, 11, 1, 23, 59);
    final model = CalendarViewsModel(
      kind: CalendarViewKind.month,
      calendars: {'home': home},
      now: () => now,
    );
    var changes = 0;
    model.addListener(() => changes++);
    expect(model.today, DateTime(2026, 11));

    now = DateTime(2026, 11, 2);
    await tester.pump(const Duration(minutes: 1));

    expect((model.today, changes), (DateTime(2026, 11, 2), 1));
    // Ends the next midnight's wake before the test checks for timers.
    model.dispose();
  });
}
