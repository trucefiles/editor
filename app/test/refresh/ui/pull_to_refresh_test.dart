import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/refresh/ui/pull_to_refresh.dart';

void main() {
  late int refreshes;

  Future<void> show(WidgetTester tester) async {
    refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PullToRefresh(
            onRefresh: () async => refreshes++,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [Text('note')],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('pulling down by touch refreshes', (tester) async {
    await show(tester);

    await tester.fling(find.text('note'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(refreshes, 1);
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
