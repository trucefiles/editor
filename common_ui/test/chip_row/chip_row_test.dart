import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

void main() {
  /// A page [width] wide with a [ChipRow] of [count] chips, each 100
  /// wide and telling taps to [tapped], above a tall list; padded tap
  /// targets in the touch look.
  Future<void> show(
    WidgetTester tester, {
    required int count,
    bool touch = false,
    double width = 400,
    List<int>? tapped,
  }) async {
    tester.view
      ..physicalSize = Size(width, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          materialTapTargetSize: touch
              ? MaterialTapTargetSize.padded
              : MaterialTapTargetSize.shrinkWrap,
        ),
        home: Scaffold(
          body: ListView(
            children: [
              ChipRow(
                chips: [
                  for (var i = 0; i < count; i++)
                    GestureDetector(
                      onTap: () => tapped?.add(i),
                      child: Focus(
                        child: SizedBox(
                          width: 100,
                          height: 32,
                          child: Text('$i'),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double rowOffset(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
      .controller!
      .offset;

  double pageOffset(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;

  final before = find.byIcon(Icons.chevron_left);
  final after = find.byIcon(Icons.chevron_right);

  testWidgets('a row that fits shows no arrows', (tester) async {
    await show(tester, count: 3);
    expect(before, findsNothing);
    expect(after, findsNothing);
  });

  testWidgets('in the desktop look, an arrow shows only on a side with '
      'hidden chips; a press scrolls about the row\'s width', (tester) async {
    await show(tester, count: 10);
    expect(before, findsNothing);
    expect(after, findsOneWidget);

    await tester.tap(after);
    await tester.pumpAndSettle();
    expect(rowOffset(tester), 320, reason: '80 % of the width');
    expect(before, findsOneWidget);
    expect(after, findsOneWidget);

    await tester.tap(after);
    await tester.pumpAndSettle();
    await tester.tap(after);
    await tester.pumpAndSettle();
    expect(rowOffset(tester), 672, reason: 'stops at the end');
    expect(after, findsNothing);
  });

  testWidgets('in the touch look, no arrows show', (tester) async {
    await show(tester, count: 10, touch: true);
    expect(before, findsNothing);
    expect(after, findsNothing);
  });

  testWidgets('the plain mouse wheel scrolls the row, not the page', (
    tester,
  ) async {
    await show(tester, count: 10);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final at = tester.getCenter(find.text('1'));
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 50)));
    await tester.pump();
    expect(rowOffset(tester), 50);
    expect(pageOffset(tester), 0, reason: 'the page stays');
  });

  testWidgets('where the row can\'t scroll, the wheel scrolls the page', (
    tester,
  ) async {
    await show(tester, count: 3);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.text('1'))),
    );
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 50)));
    await tester.pump();
    expect(pageOffset(tester), 50);
  });

  testWidgets('a chip under the fade but beside the arrow takes taps', (
    tester,
  ) async {
    final tapped = <int>[];
    await show(tester, count: 10, tapped: tapped);
    final arrow = tester.getRect(find.byType(IconButton));
    // Chip 3 lies from 324 to 424, its start under the fade.
    await tester.tapAt(Offset(arrow.left - 4, arrow.center.dy));
    expect(tapped, [3]);
  });

  testWidgets('an arrow goes once the row grows to fit', (tester) async {
    await show(tester, count: 5);
    expect(after, findsOneWidget);
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();
    expect(after, findsNothing);
  });

  testWidgets('a chip reached by Tab scrolls clear of the arrows', (
    tester,
  ) async {
    await show(tester, count: 10);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    final chip = tester.getRect(find.text('3'));
    for (final arrow in find.byType(IconButton).evaluate()) {
      final box = tester.getRect(find.byWidget(arrow.widget));
      expect(chip.overlaps(box), isFalse);
    }
    expect(rowOffset(tester), greaterThan(0));
  });
}
