import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/commit.dart';
import 'package:truce_markdown/src/edit/shown/rows.dart';
import 'package:truce_markdown/src/edit/shown/selection.dart';
import 'package:truce_markdown/src/edit/shown/shown_document.dart';
import 'package:truce_markdown/src/edit/shown/slot.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

ShownDocument _document(String text) => ShownDocument(DocumentTree.read(text));

/// The text slot of row [index].
Slot _slot(ShownDocument document, int index) =>
    (document.rows[index] as TextRow).slot;

Edited _type(ShownDocument document, int row, int offset, String text) => run(
  document,
  InsertText(Place(_slot(document, row), offset), text, Formatting.plain),
);

/// What each row shows.
List<String> _shown(ShownDocument document) => [
  for (final row in document.rows)
    switch (row) {
      TextRow(:final slot) => document.textOf(slot).text,
      BlockRow(:final leaf) => '[${leaf.runtimeType}]',
    },
];

void main() {
  test('typing changes only the line typed on', () {
    final (:document, :selection) = _type(_document('a\nb'), 0, 3, '!');
    expect(document.tree.text, 'a\nb!');
    expect(selection, TextSelection.caret(Place(_slot(document, 0), 4)));
  });

  test('a space typed at the end shows until text follows it', () {
    final spaced = _type(_document('a'), 0, 1, ' ').document;
    expect(spaced.tree.text, 'a');
    expect(_shown(spaced), ['a ']);
    final typed = _type(spaced, 0, 2, 'b').document;
    expect(typed.tree.text, 'a b');
    expect(typed.tails, isEmpty);
  });

  test('a paragraph emptied shows as a gap until it gets text', () {
    final document = _document('a\n\nb');
    final emptied = run(
      document,
      DeleteRange(
        TextSelection(
          Place(_slot(document, 1), 0),
          Place(_slot(document, 1), 1),
        ),
      ),
    );
    expect(emptied.document.tree.text, 'a');
    expect(_shown(emptied.document), ['a', '']);
    final gap = _slot(emptied.document, 1);
    expect(gap, isA<GapSlot>());
    expect(emptied.selection, TextSelection.caret(Place(gap, 0)));
    final typed = _type(emptied.document, 1, 0, 'c');
    expect(typed.document.tree.text, 'a\n\nc');
    expect(typed.document.gaps, isEmpty);
    expect(
      typed.selection,
      TextSelection.caret(Place(_slot(typed.document, 1), 1)),
    );
  });

  test('an empty item writes its text once it gets some', () {
    final spaced = _type(_document('- a\n-'), 1, 0, ' ').document;
    expect(spaced.tree.text, '- a\n-');
    expect(_shown(spaced), ['a', ' ']);
    final typed = _type(spaced, 1, 1, 'b').document;
    expect(typed.tree.text, '- a\n- &#32;b');
  });

  test('an item emptied keeps its marker', () {
    final document = _document('- a\n- b');
    final emptied = run(
      document,
      DeleteRange(
        TextSelection(
          Place(_slot(document, 1), 0),
          Place(_slot(document, 1), 1),
        ),
      ),
    );
    expect(emptied.document.tree.text, '- a\n-');
    expect(_slot(emptied.document, 1), isA<ItemSlot>());
  });

  test('text typed after a last block without text writes a paragraph', () {
    final document = _document('```\ncode\n```');
    expect(_slot(document, 1), const GapSlot(GapId.end));
    expect(_type(document, 1, 0, 'x').document.tree.text, '```\ncode\n```\nx');
    expect(_type(_document(''), 0, 0, 'x').document.tree.text, 'x');
  });

  test('a gap in a list splits it once it gets text', () {
    final tree = DocumentTree.read('1. a\n2. b\n3. c');
    final list = tree.root.children.single as ListBlock;
    final document = ShownDocument(
      tree,
      gaps: [Gap(GapId.first, container: list.id, after: list.items[1].id)],
    );
    expect(_shown(document), ['a', 'b', '', 'c']);
    expect(
      _type(document, 2, 0, 'x').document.tree.text,
      '1. a\n2. b\n\nx\n\n3. c',
    );
  });

  test('a reference link next to another stays one', () {
    final document = _document('[r]: u\n\nSee [r] and [other][r].');
    final slot = _slot(document, 1);
    final edited = run(
      document,
      DeleteRange(TextSelection(Place(slot, 5), Place(slot, 13))),
    );
    expect(edited.document.tree.text, '[r]: u\n\nSee [r][][er][r].');
  });

  test('text left reading as an HTML block becomes one', () {
    final document = _document('<strong>a\n\nb');
    final slot = _slot(document, 0);
    final edited = run(
      document,
      DeleteRange(TextSelection(Place(slot, 1), Place(slot, 2))),
    );
    expect(edited.document.tree.text, '<strong>\n\nb');
    expect(edited.document.tree.root.children.first, isA<HtmlBlock>());
    final caret = (edited.selection as TextSelection).extent;
    expect(edited.document.textOf(caret.slot).text, 'b');
    expect(caret.offset, 0);
  });

  test('a key over text left reading as an HTML block does no more', () {
    final document = _document('a<style>');
    final slot = _slot(document, 0);
    final edited = run(
      document,
      LineBreak(TextSelection(Place(slot, 0), Place(slot, 1))),
    );
    expect(edited.document.tree.text, '<style>');
    expect(edited.selection, isA<BlockSelection>());
  });

  test('a line break in code ends the code and goes on after it', () {
    final document = _document('`ab`');
    final broken = run(
      document,
      LineBreak(TextSelection.caret(Place(_slot(document, 0), 1))),
    ).document;
    expect(broken.tree.text, '`a`\\\n`b`');
  });

  test('a line break at the end shows until text follows it', () {
    final document = _document('a');
    final broken = run(
      document,
      LineBreak(TextSelection.caret(Place(_slot(document, 0), 1))),
    ).document;
    expect(broken.tree.text, 'a');
    expect(_shown(broken), ['a\n']);
    expect(_type(broken, 0, 2, 'b').document.tree.text, 'a\\\nb');
  });

  test('a replacement keeps the formatting of what stays', () {
    final document = _document('**helo** you');
    final edited = run(
      document,
      ReplaceText(
        TextSelection(
          Place(_slot(document, 0), 0),
          Place(_slot(document, 0), 4),
        ),
        'hello',
      ),
    );
    expect(edited.document.tree.text, '**hello** you');
  });

  test('typing a web address makes it a link', () {
    final linked = _type(_document('see'), 0, 3, ' www.x.org').document;
    expect(linked.tree.text, 'see www.x.org');
    final text = linked.textOf(_slot(linked, 0));
    expect(text.pieces.last.formatting.link?.destination, 'http://www.x.org');
  });
}
