import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/views/day_cells.dart';
import 'package:truce_calendar_editor/src/views/health_days.dart';

void main() {
  final today = DateTime(2026, 11, 3);
  // Periods a month apart: the next is likely around November 26.
  final health = HealthDays.of({
    'me': [DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 29)].fold(
      Calendar.read(newCalendarText('Me', health: true))!,
      (calendar, day) => applyEdit(
        calendar,
        AddEvent(
          'p$day',
          EventDraft.health(const Period(PeriodFlow.medium), day),
          at: DateTime.utc(2026, 11),
        ),
      ),
    ),
  }, today);
  final likely = DateTime(2026, 11, 26);

  /// Shows the month view's cell of [date].
  Future<void> show(
    WidgetTester tester,
    DateTime date, {
    required bool isToday,
  }) => tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 60,
        height: 60,
        child: Builder(
          builder: (context) => dayCells(health)(
            context,
            MonthDayCellDetails(
              date: date,
              isToday: isToday,
              isInFocusedMonth: true,
            ),
          ),
        ),
      ),
    ),
  );

  Color? outline(WidgetTester tester) => switch (tester
      .widget<Container>(find.byType(Container))
      .foregroundDecoration) {
    BoxDecoration(border: Border(top: BorderSide(:final color))) => color,
    _ => null,
  };

  bool striped(WidgetTester tester) => find
      .byWidgetPredicate((w) => w is CustomPaint && w.painter is Stripes)
      .evaluate()
      .isNotEmpty;

  testWidgets('today is outlined in the primary color', (tester) async {
    await show(tester, today, isToday: true);
    final primary = Theme.of(tester.element(find.byType(Container)))
        .colorScheme
        .primary;

    expect(outline(tester), primary);
    expect(striped(tester), isFalse);
  });

  testWidgets('a likely period day is striped, with no outline', (
    tester,
  ) async {
    expect(health.of(likely).likelyPeriod, isTrue);
    await show(tester, likely, isToday: false);

    expect(striped(tester), isTrue);
    expect(outline(tester), isNull);
  });

  testWidgets('today on a likely period day shows both', (tester) async {
    await show(tester, likely, isToday: true);

    expect(striped(tester), isTrue);
    expect(outline(tester), isNotNull);
  });

  testWidgets('the legend shows the stripes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CycleLegend())),
    );

    expect(striped(tester), isTrue);
  });
}
