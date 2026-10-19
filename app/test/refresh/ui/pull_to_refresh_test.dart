import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/refresh/ui/pull_to_refresh.dart';

void main() {
  late int refreshes;
  late ScrollController scroll;

  /// Shows a list of [lines], the first one 'note'; [physics] as the
  /// list sets them.
  Future<void> show(
    WidgetTester tester, {
    int lines = 1,
    ScrollPhysics? physics = const AlwaysScrollableScrollPhysics(),
  }) async {
    refreshes = 0;
    scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PullToRefresh(
            onRefresh: () async => refreshes++,
            child: ListView(
              controller: scroll,
              physics: physics,
              children: [
                const Text('note'),
                for (var i = 1; i < lines; i++)
                  SizedBox(height: 50, child: Text('line $i')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Moves [gesture] by [by] in small steps, as a finger does.
  Future<void> drag(WidgetTester tester, TestGesture gesture, Offset by) async {
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(by / 10);
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('pulling down by touch refreshes', (tester) async {
    await show(tester);

    await tester.fling(find.text('note'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });

  testWidgets('pulls a short list whose physics come from above', (
    tester,
  ) async {
    await show(tester, physics: null);

    await tester.fling(find.text('note'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });

  testWidgets('the indicator shows a while, even when refreshing is quick', (
    tester,
  ) async {
    await show(tester);

    await tester.fling(find.text('note'), const Offset(0, 300), 1000);
    while (refreshes == 0) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  testWidgets('taking a pull back first hides the indicator, then scrolls', (
    tester,
  ) async {
    await show(tester, lines: 40);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('note')),
    );

    await drag(tester, gesture, const Offset(0, 100));
    await drag(tester, gesture, const Offset(0, -100));
    expect(scroll.offset, 0, reason: 'the note stays put');

    await drag(tester, gesture, const Offset(0, -100));
    expect(scroll.offset, greaterThan(50));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(refreshes, 0);
  });

  testWidgets('scrolling up with a trackpad does not refresh', (tester) async {
    await show(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('note')),
      kind: PointerDeviceKind.trackpad,
    );
    for (var i = 1; i <= 10; i++) {
      await gesture.panZoomUpdate(
        tester.getCenter(find.text('note')),
        pan: Offset(0, 40.0 * i),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();

    expect(refreshes, 0);
  });

  testWidgets('scrolling up with a mouse wheel does not refresh', (
    tester,
  ) async {
    await show(tester);

    final mouse = TestPointer(1, PointerDeviceKind.mouse)
      ..hover(tester.getCenter(find.text('note')));
    for (var i = 0; i < 10; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(refreshes, 0);
  });
}
