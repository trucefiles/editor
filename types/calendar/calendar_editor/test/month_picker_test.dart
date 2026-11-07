import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar_editor/src/views/month_picker.dart';

void main() {
  testWidgets('months outside the range can not be picked; the year '
      'arrows stop at its ends', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await pickMonth(
              context,
              shown: DateTime(2026, 5, 9),
              today: DateTime(2026, 5, 9),
              first: DateTime(2026, 3, 15),
              last: DateTime(2027, 10, 2),
            ),
            child: const Text('Pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feb'));
    await tester.pumpAndSettle();
    expect(find.text('May 2026'), findsOneWidget, reason: 'still May');
    final previous = find.byTooltip('Previous year');
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: previous, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Next year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nov'));
    await tester.pumpAndSettle();
    expect(find.text('May 2026'), findsOneWidget, reason: 'after the last');
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(picked, DateTime(2027, 3));
  });

  /// Opens the picker on May 2026 over 1900 to 2099, the pick added to
  /// [picked].
  Future<void> open(WidgetTester tester, List<DateTime?> picked) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked.add(
              await pickMonth(
                context,
                shown: DateTime(2026, 5),
                today: DateTime(2026, 5, 9),
                first: DateTime(1900),
                last: DateTime(2099, 12, 31),
              ),
            ),
            child: const Text('Pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
  }

  testWidgets('fits a short window: the months shrink, OK stays', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 380)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picked = <DateTime?>[];
    await open(tester, picked);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked, [DateTime(2026, 5)]);
  });

  testWidgets('the year list marks the year shown, not the picked one', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester, []);
    for (final _ in Iterable<int>.generate(4)) {
      await tester.tap(find.byTooltip('Next year'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('2030'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('2030').last).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });
}
