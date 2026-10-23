import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/text_zoom/ui/wheel_to_zoom.dart';

void main() {
  late List<bool> asked;
  final scroll = ScrollController();

  /// [WheelToZoom] over a list that scrolls, scrolled down a bit.
  Future<void> show(WidgetTester tester) async {
    asked = [];
    await tester.pumpWidget(
      MaterialApp(
        home: WheelToZoom(
          onZoom: asked.add,
          child: ListView(
            controller: scroll,
            children: [
              for (final row in Iterable<int>.generate(50))
                SizedBox(height: 50, child: Text('$row')),
            ],
          ),
        ),
      ),
    );
    scroll.jumpTo(500);
  }

  Future<void> turnWheel(WidgetTester tester, double dy) async {
    final mouse = TestPointer(1, PointerDeviceKind.mouse)
      ..hover(tester.getCenter(find.byType(ListView)));
    await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
    await tester.pump();
  }

  testWidgets('with Ctrl, the wheel zooms, a notch a step, and scrolls not', (
    tester,
  ) async {
    await show(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await turnWheel(tester, -50);
    await turnWheel(tester, 50);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(asked, [true, false]);
    expect(scroll.offset, 500);
  });

  testWidgets('without Ctrl, the wheel scrolls', (tester) async {
    await show(tester);
    await turnWheel(tester, 50);

    expect(asked, isEmpty);
    expect(scroll.offset, 550);
  });
}
