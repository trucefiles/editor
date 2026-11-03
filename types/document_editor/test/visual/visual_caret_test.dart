import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems;

/// When Visual edit shows a caret: none on opening a file, none after a
/// control, so the view never jumps to an old one.
void main() {
  DocumentSelection? selection() =>
      SuperEditorInspector.findDocumentSelection();

  double scrolled(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;

  testWidgets('an existing file opens without a caret', (tester) async {
    await pumpDocument(tester, TestDocument('- [ ] milk'));
    expect(selection(), isNull);
  });

  testWidgets('a new file opens with the caret in it', (tester) async {
    await pumpDocument(tester, TestDocument('', isNew: true));
    expect(selection(), isNotNull);
  });

  testWidgets('a tap on a box takes the caret and the keyboard away; a tap '
      'into text brings them back', (tester) async {
    final document = TestDocument(
      '- [ ] milk\n- [ ] eggs',
      checkedItems: CheckedItems.moveToEnd,
    );
    await pumpDocument(tester, document);
    await tester.caretIn(checkboxNodeOf(index: 1), 2);
    expect(SuperEditorInspector.hasFocus(), isTrue);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(selection(), isNull);
    expect(SuperEditorInspector.hasFocus(), isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(document.text, '- [ ] eggs\n- [x] milk');

    await tester.caretIn(checkboxNodeOf(index: 1), 2);
    expect(selection(), isNotNull);
    expect(SuperEditorInspector.hasFocus(), isTrue);
  });

  testWidgets('a drop far below the caret leaves the view where it is', (
    tester,
  ) async {
    final lines = [for (var line = 0; line < 40; line++) 'line $line'];
    final document = TestDocument(
      '${lines.join('\n\n')}\n\n- [ ] aaa\n- [ ] bbb\n- [ ] ccc',
    );
    await pumpDocument(tester, document);
    await tester.caretIn(paragraphNodeOf(), 0);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    final before = scrolled(tester);
    expect(before, greaterThan(0));

    final handles = find.byIcon(Icons.drag_indicator);
    final gesture = await tester.startGesture(
      tester.getCenter(handles.at(0)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    final step =
        tester.getCenter(handles.at(1)).dy - tester.getCenter(handles.at(0)).dy;
    for (final _ in Iterable<int>.generate(24)) {
      await gesture.moveBy(Offset(0, step * 1.5 / 24));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(document.text, endsWith('- [ ] bbb\n- [ ] aaa\n- [ ] ccc'));
    expect(selection(), isNull);
    expect(scrolled(tester), before);
  });
}
