import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/view/rows.dart';

import '../support/shown.dart';

/// [text] after a divider is added with the caret at row [index],
/// [offset]; and the row the caret is at the start of after.
(String, int) _added(String text, int index, int offset) {
  final document = Shown.read(text);
  final edited = document.run(AddDivider(document.place(index, offset).leaf));
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

  test("in a Done section is a checked item, so it stays by the caret's "
      'item', () {
    final document = Shown.read('- [x] a\n- [ ] b', done: DoneSections());
    final edited = document.run(AddDivider(document.place(1, 1).leaf));
    expect(edited.document.text, '- [x] a\n- [x] ***\n- [ ] b');
    expect(edited.document.rows, ['b', 'done a', '[DividerNode]']);
  });

  test('in a list with * markers is written so it reads back as one', () {
    final (text, _) = _added('* a\n* b', 0, 1);
    expect(text, '* a\n* ---\n* b');
    expect(Shown.read(text).rows, ['a', '[DividerNode]', 'b']);
  });

  test('after a selected divider is another one right after it', () {
    final document = Shown.read('a\n\n---\n\nb');
    final divider = document.view.rows.whereType<BlockRow>().first.leaf;
    final edited = document.run(AddDivider(divider.id));
    expect(edited.document.text, 'a\n\n---\n\n---\n\nb');
    expect(edited.selection, edited.document.caret(3, 0));
  });

  test('after a selected separator item is another separator item', () {
    final document = Shown.read('- [ ] a\n- [ ] ***\n- [ ] b');
    final divider = document.view.rows.whereType<BlockRow>().first.leaf;
    final edited = document.run(AddDivider(divider.id));
    expect(edited.document.text, '- [ ] a\n- [ ] ***\n- [ ] ***\n- [ ] b');
  });

  test('after an item with subitems goes after its subitems', () {
    final (text, _) = _added('- a\n  - b\n- c', 0, 0);
    expect(text, '- a\n  - b\n- ***\n- c');
  });

  test('on an empty paragraph takes its place', () {
    final document = Shown.read('---');
    final edited = document.run(AddDivider(document.place(1, 0).leaf));
    expect(edited.document.text, startsWith('---\n\n---'));
    expect(edited.document.rows, ['[DividerNode]', '[DividerNode]', '']);
  });

  test('on an empty item takes its place; the caret to the next item', () {
    final (text, row) = _added('- [ ] a\n- [ ] \n- [ ] b', 1, 0);
    expect(text, '- [ ] a\n- [ ] ***\n- [ ] b');
    expect(row, 2);
  });

  test('on an empty last item takes its place; the caret into a new empty '
      'item after it', () {
    final (text, row) = _added('- [ ] a\n- [ ] ', 1, 0);
    expect(text, '- [ ] a\n- [ ] ***\n- [ ] ');
    expect(row, 2);
  });
}
