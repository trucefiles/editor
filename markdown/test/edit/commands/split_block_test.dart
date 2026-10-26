import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/view/rows.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

import '../support/shown.dart';

({Shown document, Selection selection}) _enter(
  Shown document,
  int row,
  int offset,
) => document.run(SplitBlock(document.caret(row, offset)));

void main() {
  test('Enter in a paragraph starts a new one with the text after it', () {
    final (:document, :selection) = _enter(Shown.read('ab'), 0, 1);
    expect(document.text, 'a\n\nb');
    expect(selection, document.caret(1, 0));
  });

  test('Enter between words drops the space the new line starts with', () {
    final (:document, :selection) = _enter(Shown.read('Hello  world'), 0, 5);
    expect(document.text, 'Hello\n\nworld');
    expect(selection, document.caret(1, 0));
    expect(_enter(Shown.read('- a b'), 0, 1).document.text, '- a\n- b');
  });

  test('Enter at a paragraph\'s end shows an empty one below', () {
    final (:document, :selection) = _enter(Shown.read('a\n\nb'), 0, 1);
    expect(document.text, 'a\n\nb');
    expect(document.rows, ['a', '', 'b']);
    expect(selection, document.caret(1, 0));
    final typed = document.run(
      InsertText(document.place(1, 0), 'x', Formatting.plain),
    );
    expect(typed.document.text, 'a\n\nx\n\nb');
  });

  test('Enter at a paragraph\'s start shows an empty one above', () {
    final (:document, :selection) = _enter(Shown.read('a\n\nb'), 1, 0);
    expect(document.text, 'a\n\nb');
    expect(document.rows, ['a', '', 'b']);
    expect(selection, document.caret(2, 0));
  });

  test('Enter twice shows two empty paragraphs in order', () {
    final once = _enter(Shown.read('a'), 0, 1);
    final twice = once.document.run(
      SplitBlock(once.selection as TextSelection),
    );
    expect(twice.document.rows, ['a', '', '']);
    expect(twice.selection, twice.document.caret(2, 0));
  });

  test('Enter after a heading starts a paragraph', () {
    final (:document, selection: _) = _enter(Shown.read('# Title'), 0, 5);
    expect(document.text, '# Title');
    expect(document.rows, ['Title', '']);
    expect(document.doc.root.children.first, isA<HeadingNode>());
    expect(document.doc.root.children.last, isA<ParagraphNode>());
  });

  test('Enter in an item makes a new item with the text after the caret', () {
    final (:document, :selection) = _enter(Shown.read('- ab\n  - c'), 0, 1);
    expect(document.text, '- a\n- b\n  - c');
    expect(selection, document.caret(1, 0));
  });

  test('Enter at an item\'s end makes an empty item', () {
    final (:document, :selection) = _enter(Shown.read('- [x] a'), 0, 1);
    expect(document.text, '- [x] a\n- [ ] ');
    expect(document.rows, ['a', '']);
    expect(selection, document.caret(1, 0));
  });

  test('Enter at an item\'s start makes an empty item above', () {
    final (:document, :selection) = _enter(Shown.read('- a'), 0, 0);
    expect(document.text, '-\n- a');
    expect(selection, document.caret(1, 0));
  });

  test('Enter in a Done section makes a checked item right below', () {
    final (:document, selection: _) = _enter(
      Shown.read('- [x] a\n- [ ] b', done: DoneSections()),
      1,
      1,
    );
    expect(document.text, '- [x] a\n- [x] \n- [ ] b');
    expect(document.rows, ['b', 'done a', 'done ']);
  });

  test('Enter in code is a line break in it', () {
    expect(
      _enter(Shown.read('```\nab\n```'), 0, 1).document.text,
      '```\na\nb\n```',
    );
  });

  test('Enter over a selection splits where its text was', () {
    final document = Shown.read('abcd');
    final edited = document.run(
      SplitBlock(TextSelection(document.place(0, 1), document.place(0, 3))),
    );
    expect(edited.document.text, 'a\n\nd');
  });

  test('Shift+Enter over a selection puts a line break for its text', () {
    final document = Shown.read('abcd');
    final edited = document.run(
      LineBreak(TextSelection(document.place(0, 1), document.place(0, 3))),
    );
    expect(edited.document.text, 'a\\\nd');
  });
}
