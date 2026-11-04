import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

/// A calendar named [name] with [event] on 3 November 2026 from [hour]
/// for an hour.
Calendar _calendar(String name, String event, int hour) => applyEdit(
  Calendar.read(newCalendarText(name))!,
  AddEvent(
    event,
    EventDraft(
      summary: event,
      start: Floating(DateTime.utc(2026, 11, 3, hour)),
      end: Floating(DateTime.utc(2026, 11, 3, hour + 1)),
    ),
    at: DateTime.utc(2026, 11),
  ),
);

void main() {
  testWidgets('views that only show (as the Calendar tab does): a tap on '
      'an event tells its calendar; nothing drags or adds', (tester) async {
    final tapped = <(String, String)>[];
    final home = _calendar('Home', 'Dentist', 9);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarViews<String>(
            calendars: {'home': home, 'work': _calendar('Work', 'Review', 14)},
            colorOf: (_) => Colors.teal,
            kind: CalendarViewKind.day,
            onKind: (_) {},
            now: () => DateTime(2026, 11, 3, 8),
            onTap: (calendar, occurrence) =>
                tapped.add((calendar, occurrence.part.summary)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final interaction = tester
        .widget<KalenderView>(find.byType(KalenderView))
        .interaction!;
    expect(
      (
        interaction.allowRescheduling,
        interaction.allowResizing,
        interaction.allowEventCreation,
      ),
      (false, false, false),
    );
    expect(find.byTooltip('Add event'), findsNothing);

    final dentist = tester.getCenter(find.text('Dentist'));
    final gesture = await tester.startGesture(
      dentist,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 84));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('Dentist')), dentist, reason: 'stays');

    await tester.tap(find.text('Dentist'));
    await tester.pumpAndSettle();
    expect(tapped, [('home', 'Dentist')]);
  });

  testWidgets('the schedule keeps showing what is further down and on the '
      'next page', (tester) async {
    Calendar on(String event, DateTime day) => applyEdit(
      Calendar.read(newCalendarText(event))!,
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarViews<String>(
            calendars: {
              'a': on('Early', DateTime(2026, 11, 5)),
              'b': on('Late', DateTime(2026, 11, 20)),
              'c': on('Party', DateTime(2026, 12, 7)),
            },
            colorOf: (_) => Colors.teal,
            kind: CalendarViewKind.schedule,
            onKind: (_) {},
            now: () => DateTime(2026, 11, 3, 8),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Late'), findsOneWidget);

    await tester.drag(find.text('Early'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Late'), findsOneWidget);

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Party'), findsOneWidget);
  });

  testWidgets('at very large text on a phone, all day numbers of the month '
      'show at one size', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: 3,
          maxScaleFactor: 3,
          child: Scaffold(
            body: CalendarViews<String>(
              calendars: {'home': _calendar('Home', 'Dentist', 9)},
              colorOf: (_) => Colors.teal,
              kind: CalendarViewKind.month,
              onKind: (_) {},
              now: () => DateTime(2026, 11, 3, 8),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // As shown, after each number shrank to fit.
    double heightOf(String day) => tester.getRect(find.text(day).first).height;
    expect(heightOf('9'), closeTo(heightOf('10'), 0.5));
  });

  for (final (kind, sixOn) in [
    (CalendarViewKind.month, DateTime(2027, 5)),
    (CalendarViewKind.week, DateTime(2026, 12, 14)),
    (CalendarViewKind.day, DateTime(2026, 11, 9)),
    (CalendarViewKind.schedule, DateTime(2027, 5)),
  ]) {
    testWidgets('quick taps on Next in the ${kind.name} view each move a '
        'page', (tester) async {
      await _showViews(tester, kind);
      final shown = tester
          .widget<KalenderView>(find.byType(KalenderView))
          .kalenderController;

      for (final _ in Iterable<int>.generate(6)) {
        await tester.tap(find.byTooltip('Next'));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      final range = shown.visibleDateTimeRange.value;
      expect(
        !sixOn.isBefore(range.start) && sixOn.isBefore(range.end),
        isTrue,
        reason: '$sixOn in ${range.start} to ${range.end}',
      );
    });
  }

  for (final kind in [CalendarViewKind.month, CalendarViewKind.week]) {
    testWidgets('Shift and the mouse wheel page the ${kind.name} view one '
        'step per wheel step', (tester) async {
      await _showViews(tester, kind);
      final shown = tester
          .widget<KalenderView>(find.byType(KalenderView))
          .kalenderController;
      DateTime start() => shown.visibleDateTimeRange.value.start;
      final first = start();

      await _shiftWheel(tester, 40);
      final next = start();
      expect(next.isAfter(first), isTrue);

      await _shiftWheel(tester, -40);
      expect(start(), first);
    });
  }

  testWidgets('the mouse wheel alone still scrolls the week view, not its '
      'pages', (tester) async {
    await _showViews(tester, CalendarViewKind.week);
    final shown = tester
        .widget<KalenderView>(find.byType(KalenderView))
        .kalenderController;
    final first = shown.visibleDateTimeRange.value.start;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final at = tester.getCenter(find.byType(KalenderView));
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
    await tester.pumpAndSettle();

    expect(shown.visibleDateTimeRange.value.start, first);
  });

  testWidgets("a calendar's new color shows on its events", (tester) async {
    Future<void> show(Color color) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarViews<String>(
            calendars: {'home': _calendar('Home', 'Dentist', 9)},
            colorOf: (_) => color,
            kind: CalendarViewKind.day,
            onKind: (_) {},
            now: () => DateTime(2026, 11, 3, 8),
          ),
        ),
      ),
    );
    Color? tileColor() =>
        (tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: find.text('Dentist'),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration?)
            ?.color;

    await show(Colors.teal);
    await tester.pumpAndSettle();
    expect(tileColor(), Colors.teal);

    await show(Colors.orange);
    await tester.pumpAndSettle();
    expect(tileColor(), Colors.orange);
  });

  testWidgets('one health calendar\'s cycle line goes without its name; '
      'two are named', (tester) async {
    Calendar me(String name) => applyEdit(
      Calendar.read(newCalendarText(name, health: true))!,
      AddEvent(
        'p',
        EventDraft.health(
          const Period(PeriodFlow.medium),
          DateTime.utc(2026, 11, 1),
        ),
        at: DateTime.utc(2026, 11),
      ),
    );
    Future<void> show(Map<String, Calendar> calendars) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarViews<String>(
              calendars: calendars,
              colorOf: (_) => Colors.teal,
              kind: CalendarViewKind.month,
              onKind: (_) {},
              now: () => DateTime(2026, 11, 3, 8),
              titleOf: (name) => name,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show({'Me': me('Me'), 'Work': _calendar('Work', 'Review', 14)});
    expect(find.textContaining('of the cycle'), findsOne);
    expect(find.textContaining('Me: '), findsNothing);

    await show({'Me': me('Me'), 'Ann': me('Ann')});
    expect(find.textContaining('Me: '), findsOne);
    expect(find.textContaining('Ann: '), findsOne);
  });
}

/// Shows [kind] of a calendar on 3 November 2026, as a page does.
Future<void> _showViews(WidgetTester tester, CalendarViewKind kind) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CalendarViews<String>(
          calendars: {'home': _calendar('Home', 'Dentist', 9)},
          colorOf: (_) => Colors.teal,
          kind: kind,
          onKind: (_) {},
          now: () => DateTime(2026, 11, 3, 8),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Turns the mouse wheel one step down ([dy] > 0) or up over the
/// calendar while Shift is held.
Future<void> _shiftWheel(WidgetTester tester, double dy) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  final at = tester.getCenter(find.byType(KalenderView));
  await tester.sendEventToBinding(pointer.hover(at));
  await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}
