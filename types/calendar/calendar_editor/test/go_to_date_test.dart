import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

import 'views_title.dart';

/// Shows an empty calendar in the [kind] view on 3 November 2026, each
/// view picked added to [picked].
Future<void> _showViews(
  WidgetTester tester,
  CalendarViewKind kind, {
  List<CalendarViewKind>? picked,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CalendarViews<String>(
          calendars: {'home': Calendar.read(newCalendarText('Home'))!},
          colorOf: (_) => Colors.teal,
          kind: kind,
          onKind: (picked ?? []).add,
          now: () => DateTime(2026, 11, 3, 8),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Whether the views show [day].
bool _shows(WidgetTester tester, DateTime day) {
  final range = tester
      .widget<KalenderView>(find.byType(KalenderView))
      .kalenderController
      .visibleDateTimeRange
      .value;
  return !day.isBefore(range.start) && day.isBefore(range.end);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("a tap on a month's day number shows that day in the day "
      'view, as a pick of the day view', (tester) async {
    final picked = <CalendarViewKind>[];
    await _showViews(tester, CalendarViewKind.month, picked: picked);

    await _tap(tester, find.text('20'));

    expect(viewsTitle('Fri, Nov 20'), findsOneWidget);
    expect(_shows(tester, DateTime(2026, 11, 20)), isTrue);
    expect(picked, [CalendarViewKind.day]);
  });

  testWidgets("a tap on a week's day header shows that day in the day view", (
    tester,
  ) async {
    await _showViews(tester, CalendarViewKind.week);

    await _tap(tester, find.text('5'));

    expect(viewsTitle('Thu, Nov 5'), findsOneWidget);
  });

  testWidgets("the week view's title picks a day, and OK shows its week", (
    tester,
  ) async {
    await _showViews(tester, CalendarViewKind.week);

    await _tap(tester, viewsTitle('November 2026'));
    await _tap(tester, find.text('25'));
    expect(_shows(tester, DateTime(2026, 11, 25)), isFalse, reason: 'not yet');
    await _tap(tester, find.text('OK'));

    expect(_shows(tester, DateTime(2026, 11, 25)), isTrue);
  });

  testWidgets("the month view's title picks a month of a year from the "
      'year list', (tester) async {
    await _showViews(tester, CalendarViewKind.month);

    await _tap(tester, viewsTitle('November 2026'));
    expect(find.text('Select month'), findsOneWidget);
    await _tap(tester, find.text('2026'));
    await _tap(tester, find.text('2028'));
    await _tap(tester, find.text('Mar'));
    expect(find.text('Mar 2028'), findsOneWidget, reason: 'the headline');
    await _tap(tester, find.text('OK'));

    expect(viewsTitle('March 2028'), findsOneWidget, reason: 'the bar');
    expect(_shows(tester, DateTime(2028, 3, 15)), isTrue);
  });

  testWidgets("the month picker's arrows page its years; Cancel keeps the "
      'month shown', (tester) async {
    await _showViews(tester, CalendarViewKind.month);

    await _tap(tester, viewsTitle('November 2026'));
    await _tap(tester, find.byTooltip('Next year'));
    expect(find.text('2027'), findsOneWidget);
    await _tap(tester, find.text('Feb'));
    await _tap(tester, find.text('Cancel'));
    expect(viewsTitle('November 2026'), findsOneWidget);

    await _tap(tester, viewsTitle('November 2026'));
    await _tap(tester, find.byTooltip('Previous year'));
    await _tap(tester, find.text('Feb'));
    await _tap(tester, find.text('OK'));
    expect(viewsTitle('February 2025'), findsOneWidget);
  });

  testWidgets('the schedule picks a month too', (tester) async {
    await _showViews(tester, CalendarViewKind.schedule);

    await _tap(tester, viewsTitle('November 2026'));
    await _tap(tester, find.text('Jan'));
    await _tap(tester, find.text('OK'));

    expect(viewsTitle('January 2026'), findsOneWidget);
  });
}
