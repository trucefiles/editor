import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

void main() {
  Future<BuildContext> contextOf(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    return tester.element(find.byType(SizedBox));
  }

  PointerScrollEvent step(Offset delta, PointerDeviceKind kind) =>
      PointerScrollEvent(kind: kind, scrollDelta: delta);

  testWidgets('a plain wheel step goes down, a tilt sideways', (tester) async {
    final context = await contextOf(tester);
    const down = Offset(0, 50);
    const right = Offset(50, 0);
    expect(mouseWheelStep(context, step(down, PointerDeviceKind.mouse)), down);
    expect(
      mouseWheelStep(context, step(right, PointerDeviceKind.mouse)),
      right,
    );
  });

  testWidgets('with Shift held, a wheel step goes sideways', (tester) async {
    final context = await contextOf(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    expect(
      mouseWheelStep(
        context,
        step(const Offset(0, 50), PointerDeviceKind.mouse),
      ),
      const Offset(50, 0),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  });

  testWidgets("a touchpad's scroll is no wheel step", (tester) async {
    final context = await contextOf(tester);
    expect(
      mouseWheelStep(
        context,
        step(const Offset(0, 50), PointerDeviceKind.trackpad),
      ),
      isNull,
    );
  });
}
