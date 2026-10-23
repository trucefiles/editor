import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/pinch_to_zoom.dart';

void main() {
  late List<TextZoom> asked;
  late int taps;
  final scroll = ScrollController();

  /// [PinchToZoom] over a tappable list that scrolls.
  Future<void> show(WidgetTester tester) async {
    asked = [];
    taps = 0;
    var zoom = TextZoom.normal;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => PinchToZoom(
            zoom: zoom,
            onZoom: (next) => setState(() {
              asked.add(next);
              zoom = next;
            }),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: ListView(
                controller: scroll,
                children: [
                  for (final row in Iterable<int>.generate(50))
                    SizedBox(height: 50, child: Text('$row')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Two fingers at [from] apart around the middle, spread or closed to
  /// [to] apart in ten steps, both moving [down] meanwhile.
  Future<void> pinch(
    WidgetTester tester,
    double from,
    double to, {
    double down = 0,
  }) async {
    final middle = tester.getCenter(find.byType(PinchToZoom));
    final a = await tester.startGesture(middle - Offset(from / 2, 0));
    final b = await tester.startGesture(middle + Offset(from / 2, 0));
    for (var step = 1; step <= 10; step++) {
      final span = from + (to - from) * step / 10;
      final shift = Offset(0, down * step / 10);
      await a.moveTo(middle - Offset(span / 2, 0) + shift);
      await b.moveTo(middle + Offset(span / 2, 0) + shift);
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
  }

  testWidgets('spreading two fingers makes the text larger, step by step', (
    tester,
  ) async {
    await show(tester);
    await pinch(tester, 100, 200);

    expect(asked.map((zoom) => zoom.percent), [
      110,
      120,
      130,
      140,
      150,
      160,
      170,
    ]);
  });

  testWidgets('closing two fingers makes the text smaller', (tester) async {
    await show(tester);
    await pinch(tester, 200, 100);

    expect(asked.last.percent, 80);
  });

  testWidgets('a pinch takes its fingers from what they would scroll', (
    tester,
  ) async {
    await show(tester);
    scroll.jumpTo(500);
    await pinch(tester, 100, 200, down: 40);

    expect(asked, isNotEmpty);
    expect(scroll.offset, 500);
  });

  testWidgets('one finger still scrolls and taps the child', (tester) async {
    await show(tester);
    await tester.tap(find.byType(PinchToZoom));
    await tester.drag(find.byType(ListView), const Offset(0, -300));

    expect(taps, 1);
    expect(scroll.offset, greaterThan(0));
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
