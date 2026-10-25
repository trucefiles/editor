import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/shown/rows.dart';
import 'package:truce_markdown/src/edit/shown/selection.dart';
import 'package:truce_markdown/src/edit/shown/shown_document.dart';
import 'package:truce_markdown/src/edit/shown/slot.dart';
import 'package:truce_markdown/src/tree/blocks.dart';

ShownDocument _document(String text) => ShownDocument(DocumentTree.read(text));

Slot _slot(ShownDocument document, int row) =>
    (document.rows[row] as TextRow).slot;

List<String> _shown(ShownDocument document) => [
  for (final row in document.rows)
    switch (row) {
      TextRow(:final slot) => document.textOf(slot).text,
      BlockRow(:final leaf) => '[${leaf.runtimeType}]',
    },
];

String _after(String text, Command Function(ShownDocument document) command) {
  final document = _document(text);
  return run(document, command(document)).document.tree.text;
}

TextSelection _caret(ShownDocument document, int row) =>
    TextSelection.caret(Place(_slot(document, row), 0));

void main() {
  group('Backspace at a frame\'s start', () {
    test('takes a block out of its quote, which splits around it', () {
      expect(
        _after('> a\n>\n> b\n>\n> c', (n) => RemoveFrame(_slot(n, 1))),
        '> a\n\nb\n\n> c',
      );
      expect(_after('> a\n> b', (n) => RemoveFrame(_slot(n, 0))), 'a\nb');
      expect(
        _after('> a\n>\n> b', (n) => RemoveFrame(_slot(n, 0))),
        'a\n\n> b',
      );
    });

    test('makes a first item a paragraph above its list', () {
      expect(_after('- a\n- b', (n) => RemoveFrame(_slot(n, 0))), 'a\n- b');
      expect(
        _after('- a\n  - b\n- c', (n) => RemoveFrame(_slot(n, 0))),
        'a\n- b\n- c',
      );
    });

    test('makes another item a line of the item above', () {
      expect(
        _after('- a\n- b\n- c', (n) => RemoveFrame(_slot(n, 1))),
        '- a\\\n  b\n- c',
      );
      expect(
        _after('- a\n-\n- c', (n) => RemoveFrame(_slot(n, 1))),
        '- a\n- c',
      );
      expect(
        _after('- a\n  - x\n- b', (n) => RemoveFrame(_slot(n, 2))),
        '- a\n  - x\n\n  b',
      );
    });
  });

  test('Enter on an empty item ends the list there, shown only', () {
    final document = _document('- a\n-\n- c');
    final (document: left, :selection) = run(
      document,
      LeaveList(_slot(document, 1)),
    );
    expect(left.tree.text, '- a\n- c');
    expect(_shown(left), ['a', '', 'c']);
    expect(selection, TextSelection.caret(Place(_slot(left, 1), 0)));
  });

  group('indent', () {
    test('makes an item a subitem of the one above', () {
      expect(_after('- a\n- b', (n) => Indent(_caret(n, 1))), '- a\n  - b');
      expect(
        _after('- a\n  1. x\n- b', (n) => Indent(_caret(n, 2))),
        '- a\n  1. x\n  2. b',
      );
    });

    test('outdent puts an item after its parent with the items after it', () {
      expect(
        _after('- a\n  - b\n  - c', (n) => Outdent(_caret(n, 1))),
        '- a\n- b\n  - c',
      );
    });

    test('outdent from an empty paragraph in an empty item ends the list', () {
      final tree = DocumentTree.read('- a\n-');
      final empty = tree.root.children.single as ListBlock;
      final document = ShownDocument(
        tree,
        gaps: [Gap(GapId.first, container: empty.items.last.id, after: null)],
      );
      final gap = TextSelection.caret(const Place(GapSlot(GapId.first), 0));
      final edited = run(document, Outdent(gap));
      expect(edited.document.tree.text, '- a');
      expect(_shown(edited.document), ['a', '']);
    });

    test('leaving a quote\'s only list keeps the caret in the quote', () {
      final document = _document('> -');
      final edited = run(document, LeaveList(_slot(document, 0)));
      expect(_shown(edited.document), ['']);
      final at = (edited.selection as TextSelection).extent;
      expect(edited.document.rowOf(at.slot), 0);
      expect(edited.document.rows.single.path.single, isA<QuoteBlock>());
    });

    test('outdent at the top takes an item out of its list', () {
      expect(
        _after('1. a\n2. b\n3. c', (n) => Outdent(_caret(n, 1))),
        '1. a\n\nb\n\n3. c',
      );
    });
  });
}
