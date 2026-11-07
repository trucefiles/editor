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
}
