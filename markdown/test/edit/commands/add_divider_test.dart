import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';

import '../support/shown.dart';

/// [text] after a divider is added with the caret at row [index],
/// [offset]; and the row the caret is at the start of after.
(String, int) _added(String text, int index, int offset) {
  final document = Shown.read(text);
  final edited = document.run(AddDivider(document.place(index, offset)));
  final caret = edited.selection as TextSelection;
  expect(caret.isCaret, isTrue);
  expect(caret.extent.offset, 0);
  final rows = edited.document.view.rows;
  return (
    edited.document.text,
    rows.indexWhere((row) => row.leaf.id == caret.extent.leaf),
  );
}

void main() {
  test("goes after the caret's paragraph; the caret to the text after", () {
    final (text, row) = _added('ab\n\ncd', 0, 1);
    expect(text, 'ab\n\n---\n\ncd');
    expect(row, 2);
  });

  test('at the end leaves an empty text after it for the caret', () {
    final (text, row) = _added('ab', 0, 2);
    expect(text, startsWith('ab\n\n---'));
    expect(row, 2);
  });

  test('in a checklist is a separator item with an open box after the '
      "caret's item", () {
    final (text, row) = _added('- [ ] a\n- [x] b\n- [ ] c', 0, 0);
    expect(text, '- [ ] a\n- [ ] ***\n- [x] b\n- [ ] c');
    expect(row, 2);
  });

  test('in a bulleted list is an item of its own, read back as one', () {
    final (text, _) = _added('- a\n- b', 0, 1);
    expect(text, '- a\n- ***\n- b');
    expect(Shown.read(text).rows, ['a', '[DividerNode]', 'b']);
  });

  test('after an item with subitems goes after its subitems', () {
    final (text, _) = _added('- a\n  - b\n- c', 0, 0);
    expect(text, '- a\n  - b\n- ***\n- c');
  });
}
