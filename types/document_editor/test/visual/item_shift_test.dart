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

  /// The dragged copy, while it shows.
  final copy = find.byWidgetPredicate(
    (widget) => widget is Material && widget.elevation == 4,
  );

  /// Where `bbb` shows in the copy, left to right.
  double copyLeft(WidgetTester tester) => tester
      .getTopLeft(
        find.descendant(
          of: copy,
          matching: find.text('bbb', findRichText: true),
        ),
      )
      .dx;

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

  testWidgets('a change from elsewhere during a swipe: nothing indents on '
      'release', (tester) async {
    final document = TestDocument(list);
    await pumpDocument(tester, document);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('bbb', findRichText: true)),
    );
    await slide(tester, gesture, 80);
    document.changeElsewhere('- [ ] new\n$list');
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(document.text, '- [ ] new\n$list');
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

  testWidgets('a drag sideways glides from where it was let go onto the '
      'row at its new indent', (tester) async {
    final document = TestDocument(list);
    await pumpDocument(tester, document);
    final start = left(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator).at(1)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await slide(tester, gesture, 60);
    await gesture.up();
    final copies = <double>[];
    for (final _ in Iterable<int>.generate(20)) {
      await tester.pump(const Duration(milliseconds: 16));
      if (copy.evaluate().isNotEmpty) copies.add(copyLeft(tester) - start);
    }
    await tester.pumpAndSettle();

    expect(document.text, '- [ ] aaa\n  - [ ] bbb\n- [ ] ccc');
    final step = left(tester) - start;
    expect(copies.length, greaterThan(2), reason: 'the copy glides');
    expect(copies.first, closeTo(60, 1));
    expect(copies.last, closeTo(step, 1));
    for (final (index, x) in copies.indexed.skip(1)) {
      expect(x, lessThanOrEqualTo(copies[index - 1] + 0.01));
    }
  });
}
