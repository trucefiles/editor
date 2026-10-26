import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/shown/rows.dart';
import 'package:truce_markdown/src/edit/shown/selection.dart';
import 'package:truce_markdown/src/edit/shown/shown_document.dart';
import 'package:truce_markdown/src/edit/shown/slot.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

ShownDocument _document(String text, {DoneSections? done}) =>
    ShownDocument(DocumentTree.read(text), done: done);

Slot _slot(ShownDocument document, int row) =>
    (document.rows[row] as TextRow).slot;

List<String> _shown(ShownDocument document) => [
  for (final row in document.rows)
    switch (row) {
      TextRow(:final slot) => document.textOf(slot).text,
      BlockRow(:final leaf) => '[${leaf.runtimeType}]',
    },
];

({ShownDocument document, Selection selection}) _enter(
  ShownDocument document,
  int row,
  int offset,
) => run(
  document,
  SplitBlock(TextSelection.caret(Place(_slot(document, row), offset))),
);

void main() {
  test('Enter in a paragraph starts a new one with the text after it', () {
    final (:document, :selection) = _enter(_document('ab'), 0, 1);
    expect(document.tree.text, 'a\n\nb');
    expect(selection, TextSelection.caret(Place(_slot(document, 1), 0)));
  });

  test('Enter between words drops the space the new line starts with', () {
    final (:document, :selection) = _enter(_document('Hello  world'), 0, 5);
    expect(document.tree.text, 'Hello\n\nworld');
    expect(selection, TextSelection.caret(Place(_slot(document, 1), 0)));
    expect(_enter(_document('- a b'), 0, 1).document.tree.text, '- a\n- b');
  });

  test('Enter at a paragraph\'s end shows an empty one below', () {
    final (:document, :selection) = _enter(_document('a\n\nb'), 0, 1);
    expect(document.tree.text, 'a\n\nb');
    expect(_shown(document), ['a', '', 'b']);
    expect(selection, TextSelection.caret(Place(_slot(document, 1), 0)));
    final typed = run(
      document,
      InsertText(Place(_slot(document, 1), 0), 'x', Formatting.plain),
    );
    expect(typed.document.tree.text, 'a\n\nx\n\nb');
  });

  test('Enter at a paragraph\'s start shows an empty one above', () {
    final (:document, :selection) = _enter(_document('a\n\nb'), 1, 0);
    expect(document.tree.text, 'a\n\nb');
    expect(_shown(document), ['a', '', 'b']);
    expect(selection, TextSelection.caret(Place(_slot(document, 2), 0)));
  });

  test('Enter twice shows two empty paragraphs in order', () {
    final once = _enter(_document('a'), 0, 1);
    final twice = run(
      once.document,
      SplitBlock(once.selection as TextSelection),
    );
    expect(_shown(twice.document), ['a', '', '']);
    expect(
      twice.selection,
      TextSelection.caret(Place(_slot(twice.document, 2), 0)),
    );
  });

  test('Enter after a heading starts a paragraph', () {
    final (:document, selection: _) = _enter(_document('# Title'), 0, 5);
    expect(document.tree.text, '# Title');
    expect(_shown(document), ['Title', '']);
    expect(document.tree.root.children.single, isA<HeadingBlock>());
  });

  test('Enter in an item makes a new item with the text after the caret', () {
    final (:document, :selection) = _enter(_document('- ab\n  - c'), 0, 1);
    expect(document.tree.text, '- a\n- b\n  - c');
    expect(selection, TextSelection.caret(Place(_slot(document, 1), 0)));
  });

  test('Enter at an item\'s end makes an empty item', () {
    final (:document, :selection) = _enter(_document('- [x] a'), 0, 1);
    expect(document.tree.text, '- [x] a\n- [ ] ');
    expect(_slot(document, 1), isA<ItemSlot>());
    expect(selection, TextSelection.caret(Place(_slot(document, 1), 0)));
  });

  test('Enter at an item\'s start makes an empty item above', () {
    final (:document, :selection) = _enter(_document('- a'), 0, 0);
    expect(document.tree.text, '-\n- a');
    expect(selection, TextSelection.caret(Place(_slot(document, 1), 0)));
  });

  test('Enter in a Done section makes a checked item right below', () {
    final (:document, selection: _) = _enter(
      _document('- [x] a\n- [ ] b', done: DoneSections()),
      1,
      1,
    );
    expect(document.tree.text, '- [x] a\n- [x] \n- [ ] b');
    expect(_shown(document), ['b', 'a', '']);
  });

  test('Enter in code is a line break in it', () {
    expect(
      _enter(_document('```\nab\n```'), 0, 1).document.tree.text,
      '```\na\nb\n```',
    );
  });

  test('Enter over a selection splits where its text was', () {
    final document = _document('abcd');
    final edited = run(
      document,
      SplitBlock(
        TextSelection(
          Place(_slot(document, 0), 1),
          Place(_slot(document, 0), 3),
        ),
      ),
    );
    expect(edited.document.tree.text, 'a\n\nd');
  });

  test('Shift+Enter over a selection puts a line break for its text', () {
    final document = _document('abcd');
    final edited = run(
      document,
      LineBreak(
        TextSelection(
          Place(_slot(document, 0), 1),
          Place(_slot(document, 0), 3),
        ),
      ),
    );
    expect(edited.document.tree.text, 'a\\\nd');
  });
}
