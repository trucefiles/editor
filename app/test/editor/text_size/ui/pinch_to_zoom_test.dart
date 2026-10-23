import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/text_size/note_text_size.dart';
import 'package:truce_editor/editor/text_size/ui/pinch_to_zoom.dart';

void main() {
  late List<NoteTextSize> asked;
  late int taps;

  Future<void> show(WidgetTester tester) async {
    asked = [];
    taps = 0;
    var size = NoteTextSize.normal;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => PinchToZoom(
          size: size,
          onSize: (next) => setState(() {
            asked.add(next);
            size = next;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  /// Two fingers at [from] apart around the middle, spread or closed to
  /// [to] apart.
  Future<void> pinch(WidgetTester tester, double from, double to) async {
    final middle = tester.getCenter(find.byType(PinchToZoom));
    final a = await tester.startGesture(middle - Offset(from / 2, 0));
    final b = await tester.startGesture(middle + Offset(from / 2, 0));
    for (var step = 1; step <= 10; step++) {
      final span = from + (to - from) * step / 10;
      await a.moveTo(middle - Offset(span / 2, 0));
      await b.moveTo(middle + Offset(span / 2, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
  }

  testWidgets('spreading two fingers makes the text larger, step by step', (
    tester,
  ) async {
    await show(tester);
    await pinch(tester, 100, 150);

    expect(asked.map((size) => size.percent), [110, 120, 130, 140, 150]);
  });

  testWidgets('closing two fingers makes the text smaller', (tester) async {
    await show(tester);
    await pinch(tester, 200, 160);

    expect(asked.last.percent, 80);
  });

  testWidgets('one finger only reaches the child', (tester) async {
    await show(tester);
    await tester.tap(find.byType(PinchToZoom));

    expect(taps, 1);
    expect(asked, isEmpty);
  });

  testWidgets('a mouse never pinches', (tester) async {
    await show(tester);
    final middle = tester.getCenter(find.byType(PinchToZoom));
    final a = await tester.startGesture(middle, kind: PointerDeviceKind.mouse);
    final b = await tester.startGesture(middle + const Offset(50, 0));
    await b.moveBy(const Offset(100, 0));
    await a.up();
    await b.up();

    expect(asked, isEmpty);
  });
}
