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
    await tester.caretIn(nodeOf<ParagraphNode>(index: 1), 0);
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
      expect(item, isNot(isA<ParagraphNode>()));
      expect((item as TextNode).text.toPlainText(), 'milk');
    });
  }

  testWidgets('a new item keeps checked subitems with their item', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] a\n  - [x] a1\n- [ ] b');
    await pumpNoteEditor(tester, text);

    await tester.caretIn(nodeOf<TaskNode>(), 1);
    await tester.pressEnter();
    await tester.typeImeText('new');

    expect(text.text, '- [ ] a\n  - [x] a1\n- [ ] new\n- [ ] b');
  });

  testWidgets('Enter at the start of an item adds an empty one above', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] a\n- [x] milk\n- b');
    await pumpNoteEditor(tester, text, checkedItems: CheckedItems.inPlace);

    await tester.caretIn(nodeOf<TaskNode>(index: 1), 0);
    await tester.pressEnter();
    await tester.caretIn(nodeOf<ListItemNode>(), 0);
    await tester.pressEnter();
    await tester.typeImeText('x');

    expect(text.text, '- [ ] a\n- [ ] \n- [x] milk\n- \n- xb');
  });
}
