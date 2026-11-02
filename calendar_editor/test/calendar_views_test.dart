import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
}
