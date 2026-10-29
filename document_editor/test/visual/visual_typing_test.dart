import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems;

/// Typing list marks and splitting items in Visual edit.
void main() {
  /// Types [typed] on a new line below a title; returns the file text.
  Future<String> typeOnEmptyLine(WidgetTester tester, String typed) async {
    final text = TestDocument('Title');
    await pumpDocument(tester, text);
    await tester.caretIn(paragraphNodeOf(), 5);
    await tester.pressEnter();
    await tester.typeImeText(typed);
    return text.text;
  }

  // Visual edit is fully visual: typed text is literal, marks too; the
  // file escapes them, so they read back as typed.
  for (final (typed, written) in [
    ('-5 kg', r'\-5 kg'),
    ('*it* ok', r'\*it\* ok'),
    ('1.5 kg', r'1\.5 kg'),
    ('+1', r'\+1'),
    ('- milk', r'\- milk'),
    ('1. milk', r'1\. milk'),
    ('- [ ] milk', r'\- \[ ] milk'),
  ]) {
    testWidgets('a typed mark stays text: $typed', (tester) async {
      expect(await typeOnEmptyLine(tester, typed), 'Title\n\n$written');
      final row = SuperEditorInspector.findDocument()!.last;
      expect(markedItemOf(row), isNull);
      expect((row as TextNode).text.toPlainText(), typed);
    });
  }

  testWidgets('a new item keeps checked subitems with their item', (
    tester,
  ) async {
    final text = TestDocument('- [ ] a\n  - [x] a1\n- [ ] b');
    await pumpDocument(tester, text);

    await tester.caretIn(checkboxNodeOf(), 1);
    await tester.pressEnter();
    await tester.typeImeText('new');

    expect(text.text, '- [ ] a\n  - [x] a1\n- [ ] new\n- [ ] b');
  });

  testWidgets('Enter at the start of an item adds an empty one above', (
    tester,
  ) async {
    final text = TestDocument(
      '- [ ] a\n- [x] milk\n- b',
      checkedItems: CheckedItems.inPlace,
    );
    await pumpDocument(tester, text);

    await tester.caretIn(checkboxNodeOf(index: 1), 0);
    await tester.pressEnter();
    // Not a tap: the caret's touch handle lies over the start of the next,
    // compact row.
    await tester.pressDownArrow();
    await tester.pressEnter();
    await tester.typeImeText('x');

    expect(text.text, '- [ ] a\n- [ ] \n- [x] milk\n-\n- xb');
  });

  group('a line break in an item', () {
    Future<void> pressShiftEnter(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pressEnter();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    }

    testWidgets('Shift+Enter adds a line to the item, as a hard break', (
      tester,
    ) async {
      final text = TestDocument('- [ ] milk\n- [ ] eggs');
      await pumpDocument(tester, text);

      await tester.caretIn(checkboxNodeOf(), 4);
      await pressShiftEnter(tester);
      await tester.typeImeText('2 l');

      expect(text.text, '- [ ] milk\\\n  2 l\n- [ ] eggs');
    });

    testWidgets('the toolbar button adds one too', (tester) async {
      final text = TestDocument('- a b');
      await pumpDocument(tester, text);

      await tester.caretIn(listItemNodeOf(), 1);
      await tester.tap(find.byTooltip('Line break (Shift+Enter)'));
      await tester.pumpAndSettle();

      expect(text.text, '- a\\\n  b');
    });

    testWidgets('Backspace after it takes it back', (tester) async {
      final text = TestDocument('- a\\\n  b');
      await pumpDocument(tester, text);

      await tester.caretIn(listItemNodeOf(), 4);
      await tester.pressLeftArrow();
      await tester.pressBackspace();

      expect(text.text, '- ab');
    });
  });

  testWidgets('the soft keyboard deletes a line break as one too', (
    tester,
  ) async {
    final text = TestDocument('- a\\\n  b');
    await pumpDocument(tester, text);

    await tester.caretIn(listItemNodeOf(), 4);
    await tester.pressLeftArrow();
    await tester.ime.backspace(getter: imeClientGetter);

    expect(text.text, '- ab');
  });
}
