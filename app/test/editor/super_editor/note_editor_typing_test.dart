import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor/editor/checked_items.dart';

import '../editor_support.dart';
import 'editor_robot.dart';

/// Typing list marks and splitting items in Visual edit.
void main() {
  /// Types [typed] on the empty line below a title; returns the file text.
  Future<String> typeOnEmptyLine(WidgetTester tester, String typed) async {
    final text = FakeNoteText('Title\n');
    await pumpNoteEditor(tester, text);
    await tester.caretIn(paragraphNodeOf(index: 1), 0);
    await tester.typeImeText(typed);
    return text.text;
  }

  for (final typed in ['-5 kg', '*it* ok', '1.5 kg', '+1']) {
    testWidgets('a mark without a space stays text: $typed', (tester) async {
      expect(await typeOnEmptyLine(tester, typed), 'Title\n$typed');
    });
  }

  for (final (typed, kind) in [
    ('- milk', 'bullet'),
    ('* milk', 'bullet'),
    ('1. milk', 'numbered'),
    ('- [ ] milk', 'checkbox'),
  ]) {
    testWidgets('a mark and a space start a $kind item: $typed', (
      tester,
    ) async {
      expect(await typeOnEmptyLine(tester, typed), 'Title\n$typed');
      final item = SuperEditorInspector.findDocument()!.last;
      expect(markedItemOf(item), isNotNull);
      expect((item as TextNode).text.toPlainText(), 'milk');
    });
  }

  for (final typed in ['-', '1.', '- [ ]']) {
    testWidgets('a lone mark shows as an empty item once left: $typed', (
      tester,
    ) async {
      expect(await typeOnEmptyLine(tester, typed), 'Title\n$typed');
      expect(markedItemOf(SuperEditorInspector.findDocument()!.last), isNull);

      await tester.pressUpArrow();
      await tester.pumpAndSettle();

      final item = SuperEditorInspector.findDocument()!.last;
      expect(markedItemOf(item), isNotNull);
      expect((item as TextNode).text.toPlainText(), isEmpty);
    });
  }

  testWidgets('a new item keeps checked subitems with their item', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] a\n  - [x] a1\n- [ ] b');
    await pumpNoteEditor(tester, text);

    await tester.caretIn(checkboxNodeOf(), 1);
    await tester.pressEnter();
    await tester.typeImeText('new');

    expect(text.text, '- [ ] a\n  - [x] a1\n- [ ] new\n- [ ] b');
  });

  testWidgets('Enter at the start of an item adds an empty one above', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] a\n- [x] milk\n- b');
    await pumpNoteEditor(tester, text, checkedItems: CheckedItems.inPlace);

    await tester.caretIn(checkboxNodeOf(index: 1), 0);
    await tester.pressEnter();
    // Not a tap: the caret's touch handle lies over the start of the next,
    // compact row.
    await tester.pressDownArrow();
    await tester.pressEnter();
    await tester.typeImeText('x');

    expect(text.text, '- [ ] a\n- [ ] \n- [x] milk\n- \n- xb');
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
      final text = FakeNoteText('- [ ] milk\n- [ ] eggs');
      await pumpNoteEditor(tester, text);

      await tester.caretIn(checkboxNodeOf(), 4);
      await pressShiftEnter(tester);
      await tester.typeImeText('2 l');

      expect(text.text, '- [ ] milk\\\n      2 l\n- [ ] eggs');
    });

    testWidgets('the toolbar button adds one too', (tester) async {
      final text = FakeNoteText('- a b');
      await pumpNoteEditor(tester, text);

      await tester.caretIn(listItemNodeOf(), 1);
      await tester.tap(find.byTooltip('Line break (Shift+Enter)'));
      await tester.pumpAndSettle();

      expect(text.text, '- a\\\n   b');
    });

    testWidgets('Backspace after it takes it back', (tester) async {
      final text = FakeNoteText('- a\\\n  b');
      await pumpNoteEditor(tester, text);

      await tester.caretIn(listItemNodeOf(), 4);
      await tester.pressLeftArrow();
      await tester.pressBackspace();

      expect(text.text, '- ab');
    });
  });

  testWidgets('Shift+Tab in an empty subitem being typed moves only it', (
    tester,
  ) async {
    final text = FakeNoteText('- a\n  - b\n');
    await pumpNoteEditor(tester, text);
    await tester.caretIn(SuperEditorInspector.findDocument()!.last.id, 0);
    await tester.typeImeText('  -');
    expect(text.text, '- a\n  - b\n  -');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pressTab();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(text.text, '- a\n  - b\n-');
  });
}
