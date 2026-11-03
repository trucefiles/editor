import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';

/// Shifting an item sideways in Visual edit, frame by frame: on release
/// its row goes straight to its new indent, never past it.
void main() {
  const list = '- [ ] aaa\n- [ ] bbb\n- [ ] ccc';

  /// Where `bbb` shows, left to right, in its row and not in a copy.
  double left(WidgetTester tester) =>
      tester.getTopLeft(find.text('bbb', findRichText: true).last).dx;

  /// Moves [gesture] [dx] to the right, a few pixels a frame.
  Future<void> slide(WidgetTester tester, TestGesture gesture, double dx) =>
      Iterable<int>.generate(20).fold(Future.value(), (done, _) async {
        await done;
        await gesture.moveBy(Offset(dx / 20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      });

  /// Where the row shows in each frame after [gesture] lets go.
  Future<List<double>> released(
    WidgetTester tester,
    TestGesture gesture,
    double start,
  ) async {
    await gesture.up();
    final frames = <double>[];
    for (final _ in Iterable<int>.generate(20)) {
      await tester.pump(const Duration(milliseconds: 16));
      frames.add(left(tester) - start);
    }
    return frames;
  }

  testWidgets('a swipe that indents lands without a jump', (tester) async {
    final document = TestDocument(list);
    await pumpDocument(tester, document);
    final start = left(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('bbb', findRichText: true)),
    );
    await slide(tester, gesture, 80);
    final frames = await released(tester, gesture, start);

    expect(document.text, '- [ ] aaa\n  - [ ] bbb\n- [ ] ccc');
    final step = frames.last;
    expect(step, greaterThan(0));
    expect(frames, everyElement(closeTo(step, 0.5)));
  });

  testWidgets('a swipe that cannot indent slides back', (tester) async {
    final document = TestDocument('- [ ] bbb');
    await pumpDocument(tester, document);
    final start = left(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('bbb', findRichText: true)),
    );
    await slide(tester, gesture, 80);
    final frames = await released(tester, gesture, start);

    expect(document.text, '- [ ] bbb');
    expect(frames.first, greaterThan(0));
    expect(frames.last, 0);
  });

  testWidgets('a drag sideways glides to the new indent, never past it', (
    tester,
  ) async {
    final document = TestDocument(list);
    await pumpDocument(tester, document);
    final start = left(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator).at(1)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await slide(tester, gesture, 40);
    final frames = await released(tester, gesture, start);
    await tester.pumpAndSettle();

    expect(document.text, '- [ ] aaa\n  - [ ] bbb\n- [ ] ccc');
    final step = left(tester) - start;
    expect(step, greaterThan(0));
    expect(frames, everyElement(inInclusiveRange(step - 0.5, 40.5)));
    expect(frames.last, closeTo(step, 0.5));
  });
}
