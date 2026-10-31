import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/src/visual/ui/item_row.dart';
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

  /// Takes the item showing [text] by its handle and moves it until its
  /// copy's middle is [fraction] down the row showing [onto].
  Future<TestGesture> dragOnto(
    WidgetTester tester,
    String text,
    String onto, {
    double fraction = 0.3,
  }) async {
    Offset handleOf(String text) => tester.getCenter(
      find.descendant(
        of: find.ancestor(
          of: find.text(text, findRichText: true),
          matching: find.byType(ItemRow),
        ),
        matching: find.byIcon(Icons.drag_indicator),
      ),
    );
    final from = handleOf(text);
    final target = tester.getRect(
      find.ancestor(
        of: find.text(onto, findRichText: true),
        matching: find.byType(ItemRow),
      ),
    );
    final to = Offset(from.dx, target.top + target.height * fraction);
    final gesture = await tester.startGesture(
      from,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    for (final _ in Iterable<int>.generate(24)) {
      await gesture.moveBy((to - from) / 24);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    return gesture;
  }

  testWidgets('an item moves onto the top of the next list', (tester) async {
    final document = TestDocument('- [ ] aaa\n- [ ] bbb\n\n1. ccc\n2. ddd');
    await pumpDocument(tester, document);

    final gesture = await dragOnto(tester, 'bbb', 'ccc');
    await gesture.up();
    await tester.pumpAndSettle();

    expect(document.text, '- [ ] aaa\n\n1. [ ] bbb\n2. ccc\n3. ddd');
  });

  testWidgets('the gap is as high as the dragged row, also with other '
      'blocks below it, and the copy lands on its row', (tester) async {
    final document = TestDocument(
      '- [ ] aaa\n- [ ] bbb\n\npara\n\nmore\n\n- [ ] ccc\n- [ ] ddd',
    );
    await pumpDocument(tester, document);
    final before = rowTextTop(tester, 'ddd');
    final step = rowTextTop(tester, 'bbb') - rowTextTop(tester, 'aaa');

    final gesture = await dragOnto(tester, 'bbb', 'ccc', fraction: 0.7);
    expect(rowTextTop(tester, 'ddd') - before, closeTo(step, 1));
    await gesture.up();
    var landing = 0.0;
    for (final _ in Iterable<int>.generate(20)) {
      await tester.pump(const Duration(milliseconds: 16));
      if (copy.evaluate().isNotEmpty) landing = copyTextTop(tester, 'bbb');
    }
    await tester.pumpAndSettle();

    expect(
      document.text,
      '- [ ] aaa\n\npara\n\nmore\n\n- [ ] ccc\n- [ ] bbb\n- [ ] ddd',
    );
    expect(landing, closeTo(rowTextTop(tester, 'bbb'), 1));
  });

  testWidgets('with a Done section, dragged onto the top of the next row '
      'shown, no room opens and nothing moves', (tester) async {
    const text = '- [ ] aaa\n- [x] bbb\n- [ ] ccc';
    final document = TestDocument(text);
    await pumpDocument(tester, document);
    final before = rowTextTop(tester, 'ccc');

    final gesture = await dragOnto(tester, 'aaa', 'ccc');
    expect(rowTextTop(tester, 'ccc'), before);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(document.text, text);
  });
}
