import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/views/health_days.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

import 'page_harness.dart';

final _today = DateTime(2026, 11, 3);

/// The health entries [part]'s calendar holds on [day] (by default
/// [_today]).
List<HealthEntry?> _entries(CalendarEditorPart part, [DateTime? day]) {
  final on = day ?? _today;
  return [
    for (final event
        in healthByDay(calendarOf(part))[DateTime.utc(
              on.year,
              on.month,
              on.day,
            )] ??
            const <CalendarEvent>[])
      event.series.health,
  ];
}

/// Adds an entry of [kind] by Add, as the form starts it.
Future<void> _add(WidgetTester tester, String kind) async {
  await tester.tap(find.byTooltip('Add event'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(kind).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add lists the general kinds first, then the period', (
    tester,
  ) async {
    await pumpPage(
      tester,
      calendarPart(newCalendarText('Me', health: true)),
      today: _today,
    );
    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();

    final kinds = ['Medication', 'Symptom', 'Measure', 'Note', 'Period'];
    final tops = [for (final kind in kinds) tester.getTopLeft(find.text(kind))];
    expect(
      tops.map((top) => top.dy).toList(),
      orderedEquals([...tops.map((top) => top.dy)]..sort()),
    );
  });

  testWidgets('no cycle shows until a period is written; then the cycle '
      'line, its note and its marks', (tester) async {
    final part = calendarPart(newCalendarText('Me', health: true));
    await pumpPage(tester, part, today: _today);
    expect(find.textContaining('of the cycle'), findsNothing);
    expect(find.text('Likely fertile'), findsNothing);

    await _add(tester, 'Period');
    await tester.tap(find.text('heavy'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_entries(part), [const Period(PeriodFlow.heavy)]);
    expect(find.textContaining('Day 1 of the cycle'), findsOne);
    expect(find.text('Likely fertile'), findsOne);
    expect(find.text('Period: heavy'), findsOne, reason: 'its tile');
  });

  testWidgets('the cycle line shows below the calendar, clear of the Add '
      'button', (tester) async {
    final part = calendarPart(newCalendarText('Me', health: true));
    await pumpPage(tester, part, today: _today);
    await _add(tester, 'Period');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final line = tester.getRect(find.textContaining('of the cycle'));
    final legend = tester.getRect(find.text('Likely fertile'));
    final add = tester.getRect(find.byTooltip('Add event'));
    expect(
      line.top,
      greaterThan(tester.getRect(find.byType(KalenderView)).bottom - 1),
    );
    for (final text in [line, legend]) {
      expect(text.overlaps(add), isFalse);
    }
  });

  testWidgets('a symptom needs its name; the form keeps one width', (
    tester,
  ) async {
    final part = calendarPart(newCalendarText('Me', health: true));
    await pumpPage(tester, part, today: _today);

    await _add(tester, 'Symptom');
    final width = tester.getSize(find.byType(AlertDialog)).width;
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Symptom'), 'Cramps');
    await tester.pump();
    await tester.tap(find.text('Strong'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AlertDialog)).width, width);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(_entries(part), [const Symptom('Cramps', level: 3)]);
  });

  testWidgets('a tapped day gets the entry; one edited in its own form '
      'keeps its day; one deleted goes', (tester) async {
    final part = calendarPart(newCalendarText('Me', health: true));
    await pumpPage(tester, part, today: _today);
    await tester.tapAt(tester.getCenter(find.text('20')) + const Offset(0, 40));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Note'), 'Tired');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final day = DateTime(2026, 11, 20);
    expect(_entries(part, day), [const HealthNote()]);

    await tester.tap(find.text('Note').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Tired'), findsOne, reason: 'its details');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOne, reason: 'the health form');
    await tester.enterText(find.widgetWithText(TextField, 'Note'), 'Rested');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      healthByDay(calendarOf(part)).values.single.single.series.description,
      'Rested',
    );
    expect(_entries(part, day), [const HealthNote()]);

    await tester.tap(find.text('Note').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(_entries(part, day), isEmpty);
  });

  test('cycle days come only from health calendars with a period', () {
    Calendar health(List<DateTime> days) => days.fold(
      Calendar.read(newCalendarText('Me', health: true))!,
      (calendar, day) => applyEdit(
        calendar,
        AddEvent(
          'p$day',
          EventDraft.health(const Period(PeriodFlow.medium), day),
          at: DateTime.utc(2026, 11),
        ),
      ),
    );
    final days = HealthDays.of({
      'none': health([]),
      'me': health([DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 29)]),
    }, _today);
    expect(days.cycles.keys, ['me']);
    expect(days.of(DateTime(2026, 10, 29)).period, isTrue);
    expect(days.of(DateTime(2026, 11, 26)).likelyPeriod, isTrue);
    expect(HealthDays.of({'none': health([])}, _today).any, isFalse);
  });

  testWidgets('the month view tints weekends', (tester) async {
    await pumpPage(
      tester,
      calendarPart(newCalendarText('Home')),
      today: _today,
    );
    final view = tester.widget<KalenderView>(find.byType(KalenderView));
    expect(
      view.components?.monthComponents.bodyComponents.monthDayCellBuilder,
      isNotNull,
    );
  });
}
