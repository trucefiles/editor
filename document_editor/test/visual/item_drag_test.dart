import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';

/// Dragging an item in Visual edit, frame by frame: what the user sees
/// while the copy glides and the move lands.
void main() {
  const list = '- [ ] aaa\n- [ ] bbb\n- [ ] ccc\n- [ ] ddd';

  /// The dragged copy, while it shows.
  final copy = find.byWidgetPredicate(
    (widget) => widget is Material && widget.elevation == 4,
  );

  /// The top of [text] in its row, not in the copy.
  double rowTextTop(WidgetTester tester, String text) {
    final inCopy = find
        .descendant(of: copy, matching: find.text(text, findRichText: true))
        .evaluate()
        .toSet();
    final row = find
        .text(text, findRichText: true)
        .evaluate()
        .firstWhere((element) => !inCopy.contains(element));
    return tester.getTopLeft(find.byElementPredicate((e) => e == row)).dy;
  }

  double copyTextTop(WidgetTester tester, String text) => tester
      .getTopLeft(
        find.descendant(
          of: copy,
          matching: find.text(text, findRichText: true),
        ),
      )
      .dy;

  /// Takes item [index] by its handle and moves it [rows] rows down (up
  /// if negative), 48 px each, a few pixels a frame.
  Future<TestGesture> dragItem(
    WidgetTester tester,
    int index,
    double rows,
  ) async {
    final handles = find.byIcon(Icons.drag_indicator);
    final step =
        tester.getCenter(handles.at(1)).dy - tester.getCenter(handles.at(0)).dy;
    final gesture = await tester.startGesture(
      tester.getCenter(handles.at(index)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    for (final _ in Iterable<int>.generate(24)) {
      await gesture.moveBy(Offset(0, step * rows / 24));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    return gesture;
  }

  testWidgets("the copy's text lies over the row's text", (tester) async {
    await pumpDocument(tester, TestDocument(list));

    final before = rowTextTop(tester, 'bbb');
    final gesture = await dragItem(tester, 1, -0.5);
    final handles = find.byIcon(Icons.drag_indicator);
    final moved =
        (tester.getCenter(handles.at(1)).dy -
            tester.getCenter(handles.at(0)).dy) *
        0.5;

    expect(copyTextTop(tester, 'bbb'), closeTo(before - moved, 1));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  for (final (direction, index, rows, moved) in [
    ('down', 1, 1.5, 'bbb'),
    ('up', 2, -1.5, 'ccc'),
  ]) {
    testWidgets('dropped $direction, no row moves away from where it ends '
        'and the copy lands on its row', (tester) async {
      final document = TestDocument(list);
      await pumpDocument(tester, document);
      final gesture = await dragItem(tester, index, rows);

      await gesture.up();
      final tops = <double>[];
      var landing = 0.0;
      for (final _ in Iterable<int>.generate(20)) {
        await tester.pump(const Duration(milliseconds: 16));
        tops.add(rowTextTop(tester, 'ddd'));
        if (copy.evaluate().isNotEmpty) landing = copyTextTop(tester, moved);
      }
      await tester.pumpAndSettle();

      expect(document.text, '- [ ] aaa\n- [ ] ccc\n- [ ] bbb\n- [ ] ddd');
      final end = tops.last;
      // Each frame at least as near to its end as the one before.
      for (final (index, top) in tops.indexed.skip(1)) {
        expect(
          (top - end).abs(),
          lessThanOrEqualTo((tops[index - 1] - end).abs() + 0.01),
          reason: 'last row, frame by frame: $tops',
        );
      }
      expect(landing, closeTo(rowTextTop(tester, moved), 1));
    });
  }
}
