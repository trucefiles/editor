import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems;

/// Undo and redo in Visual edit show the row they change.
void main() {
  ScrollPosition scroll(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  Future<void> scrollTo(
    WidgetTester tester,
    double Function(ScrollPosition) at,
  ) async {
    final position = scroll(tester);
    position.jumpTo(at(position));
    await tester.pumpAndSettle();
  }

  double top(ScrollPosition position) => position.minScrollExtent;
  double bottom(ScrollPosition position) => position.maxScrollExtent;

  /// Whether [finder] shows whole on the screen.
  bool showsWhole(WidgetTester tester, Finder finder) {
    final screen =
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    final rect = tester.getRect(finder);
    return screen.contains(rect.topLeft) && screen.contains(rect.bottomRight);
  }

  testWidgets('scrolled away from typed text, undo and redo scroll back', (
    tester,
  ) async {
    final document = TestDocument(
      [for (var i = 0; i < 80; i++) 'line $i'].join('\n\n'),
    );
    await pumpDocument(tester, document);
    await tester.caretIn(paragraphNodeOf(), 6);
    await tester.typeImeText('!');

    await scrollTo(tester, bottom);
    document.undo();
    await tester.pumpAndSettle();
    expect(scroll(tester).pixels, top(scroll(tester)));

    await scrollTo(tester, bottom);
    document.redo();
    await tester.pumpAndSettle();
    expect(scroll(tester).pixels, top(scroll(tester)));
  });

  testWidgets('undo of a box tap scrolls to its item, with no caret', (
    tester,
  ) async {
    final document = TestDocument(
      [for (var i = 0; i < 60; i++) '- [ ] item $i'].join('\n'),
      checkedItems: CheckedItems.inPlace,
    );
    await pumpDocument(tester, document);
    await scrollTo(tester, bottom);
    await tester.tap(find.byType(Checkbox).last);
    await tester.boxTapsSent(document);

    await scrollTo(tester, top);
    document.undo();
    await tester.pumpAndSettle();

    expect(scroll(tester).pixels, greaterThan(top(scroll(tester))));
    expect(showsWhole(tester, find.byType(Checkbox).last), isTrue);
  });

  testWidgets('a row on screen already stays where it is', (tester) async {
    final document = TestDocument(
      [for (var i = 0; i < 80; i++) 'line $i'].join('\n\n'),
    );
    await pumpDocument(tester, document);
    await scrollTo(tester, (position) => 200);
    await tester.caretIn(paragraphNodeOf(index: 10), 0);
    await tester.typeImeText('x');
    final before = scroll(tester).pixels;

    document.undo();
    await tester.pumpAndSettle();

    expect(scroll(tester).pixels, before);
  });
}
