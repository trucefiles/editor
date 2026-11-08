import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

/// The one occurrence of "Swimming" on 3 November 2026, 17 to 18, in
/// red, at the pool, with notes.
Occurrence _swimming() {
  final calendar = applyEdit(
    Calendar.read(newCalendarText('Home'))!,
    AddEvent(
      'a',
      EventDraft(
        summary: 'Swimming',
        start: Floating(DateTime.utc(2026, 11, 3, 17)),
        end: Floating(DateTime.utc(2026, 11, 3, 18)),
        location: 'Pool',
        description: 'Bring a towel',
        color: const EventColor('red'),
      ),
      at: DateTime.utc(2026, 11),
    ),
  );
  return occurrences(
    calendar,
    DateTime(2026, 11, 3),
    DateTime(2026, 11, 4),
  ).single;
}

void main() {
  for (final text in [1.0, 1.5]) {
    testWidgets(
      'at text size $text, the calendar and the event have the '
      'same dot in one column, and their names start alike, as the '
      "actions' do; each part's icon sits in that column",
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = text;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showOccurrenceSheet<void>(
                    context,
                    _swimming(),
                    const [
                      (icon: Icons.edit_outlined, label: 'Edit', value: null),
                    ],
                    calendar: (color: Colors.teal, title: 'Family'),
                  ),
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        final dots = find.byType(CalendarDot);
        expect(dots, findsNWidgets(2));
        final (calendarDot, eventDot) = (
          tester.getRect(dots.first),
          tester.getRect(dots.last),
        );
        expect(eventDot.size, calendarDot.size);
        expect(eventDot.center.dx, calendarDot.center.dx);
        final textStart = tester.getTopLeft(find.text('Swimming')).dx;
        expect(tester.getTopLeft(find.text('Family')).dx, textStart);
        expect(tester.getTopLeft(find.text('Edit')).dx, textStart);
        for (final icon in [
          Icons.schedule,
          Icons.place_outlined,
          Icons.notes,
        ]) {
          expect(tester.getCenter(find.byIcon(icon)).dx, calendarDot.center.dx);
        }
        final lines = [
          'Family',
          'Swimming',
          'Pool',
          'Bring a towel',
        ].map((line) => tester.getRect(find.text(line))).toList();
        for (final (above, below) in [
          (lines[0], lines[1]),
          (lines[2], lines[3]),
        ]) {
          expect(below.top - above.bottom, greaterThanOrEqualTo(8));
        }
      },
      // Touch and desktop density.
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.linux,
      }),
    );
  }

  testWidgets('copying the whole sheet puts each line on its own line', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOccurrenceSheet<void>(
                context,
                _swimming(),
                const [],
                calendar: (color: Colors.teal, title: 'Family'),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    // A tap puts the keys in the sheet's text.
    await tester.tap(find.text('Pool'));
    await tester.pump();
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(copied?.split('\n'), [
      'Family',
      'Swimming',
      startsWith('Tuesday, November 3, 2026'),
      'Pool',
      'Bring a towel',
    ]);
  });
}
