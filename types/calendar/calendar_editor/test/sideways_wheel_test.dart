import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar_editor/src/views/sideways_wheel.dart';

void main() {
  testWidgets('moves one page at a time: steps while a page still moves '
      'are dropped', (tester) async {
    final moves = <Completer<void>>[];
    Future<void> move() => (moves..add(Completer<void>())).last.future;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SidewaysWheel(
          onPrevious: move,
          onNext: move,
          child: const SizedBox(),
        ),
      ),
    );
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    Future<void> step() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    }

    await tester.sendEventToBinding(pointer.hover(const Offset(10, 10)));
    await step();
    await step();
    await step();
    expect(moves, hasLength(1));

    moves.single.complete();
    await tester.pump();
    await step();
    expect(moves, hasLength(2));
  });
}
