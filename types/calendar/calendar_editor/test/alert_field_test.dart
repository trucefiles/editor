import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/ui/alert_field.dart';
import 'package:truce_calendar_editor/src/ui/event_form.dart';
import 'package:truce_calendar_editor/src/ui/task_form.dart';

/// What the alert field says below it, now that alerts ring.
const _rings = 'Rings for the calendars shown in the Calendars tab';

void main() {
  Future<void> pump(WidgetTester tester, Widget form) =>
      tester.pumpWidget(MaterialApp(home: form));

  testWidgets("the event form's alert says which calendars ring", (
    tester,
  ) async {
    final day = DateTime.utc(2026, 11, 3);
    await pump(
      tester,
      EventForm(
        EventDraft(summary: 'Dentist', start: AllDay(day), end: AllDay(day)),
        title: 'Edit event',
        deviceZone: null,
      ),
    );

    expect(find.text(_rings), findsOne);
    expect(find.textContaining("doesn't remind you"), findsNothing);
  });

  testWidgets("the task form's alert says which calendars ring", (
    tester,
  ) async {
    final day = DateTime(2026, 11, 3);
    await pump(
      tester,
      TaskForm(
        TaskDraft(summary: 'Pay rent', due: AllDay(day)),
        title: 'Edit task',
        deviceZone: null,
        today: day,
      ),
    );

    expect(find.text(_rings), findsOne);
    expect(find.textContaining("doesn't remind you"), findsNothing);
  });

  test('an alert reads before or after the time it counts from', () {
    expect(alertText(Duration.zero), 'At the start');
    expect(alertText(const Duration(minutes: 15)), '15 minutes before');
    expect(alertText(const Duration(hours: 1)), '1 hour before');
    expect(alertText(const Duration(days: 2)), '2 days before');
    expect(alertText(const Duration(minutes: -15)), '15 minutes after');
    expect(alertText(const Duration(hours: -1)), '1 hour after');
  });

  group('several alerts', () {
    List<Duration> shown(WidgetTester tester) =>
        tester.state<_HarnessState>(find.byType(_Harness)).alerts;

    testWidgets('Add alert adds the first time not yet used', (tester) async {
      await tester.pumpWidget(const _Harness([Duration.zero]));

      await tester.tap(find.text('Add alert'));
      await tester.pump();

      expect(shown(tester), [Duration.zero, const Duration(minutes: 5)]);
      expect(find.text('5 minutes before'), findsOne);
    });

    testWidgets('an alert is changed or removed on its own', (tester) async {
      await tester.pumpWidget(
        const _Harness([Duration.zero, Duration(minutes: 10)]),
      );

      await tester.tap(find.text('10 minutes before'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 hour before').last);
      await tester.pumpAndSettle();
      expect(shown(tester), [Duration.zero, const Duration(hours: 1)]);

      await tester.tap(find.byTooltip('Remove alert').first);
      await tester.pump();
      expect(shown(tester), [const Duration(hours: 1)]);
      // The row left shows the alert that stays.
      expect(find.text('At the start'), findsNothing);
      expect(find.text('1 hour before'), findsOne);
    });

    testWidgets("an alert's list leaves out the other alerts' times", (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Harness([Duration.zero, Duration(minutes: 10)]),
      );

      await tester.tap(find.text('10 minutes before'));
      await tester.pumpAndSettle();

      // Only the open list's own row shows the first alert's time.
      expect(find.text('At the start'), findsOne);
    });

    testWidgets('an alert the list does not offer shows and is kept', (
      tester,
    ) async {
      await tester.pumpWidget(const _Harness([Duration(minutes: 20)]));

      expect(find.text('20 minutes before'), findsOne);
      await tester.tap(find.text('Add alert'));
      await tester.pump();

      expect(shown(tester), [const Duration(minutes: 20), Duration.zero]);
    });

    testWidgets('with every time used, there is no Add alert', (tester) async {
      await tester.pumpWidget(const _Harness(alertChoices));

      expect(find.text('Add alert'), findsNothing);
    });
  });
}

/// An [AlertField] showing [alerts], which it changes as told.
class _Harness extends StatefulWidget {
  const _Harness(this.alerts);

  final List<Duration> alerts;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late var alerts = widget.alerts;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: AlertField(
        alerts: alerts,
        onAlerts: (changed) => setState(() => alerts = changed),
      ),
    ),
  );
}
