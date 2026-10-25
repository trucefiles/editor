import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/shown/rows.dart';
import 'package:truce_markdown/src/edit/shown/selection.dart';
import 'package:truce_markdown/src/edit/shown/shown_document.dart';
import 'package:truce_markdown/src/edit/shown/slot.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

/// [text] after [kind] is set on its rows [from] to [to].
String _framed(String text, FrameKind kind, [int from = 0, int? to]) {
  final document = ShownDocument(DocumentTree.read(text));
  Place place(int row) => Place((document.rows[row] as TextRow).slot, 0);
  return run(
    document,
    SetFrame(TextSelection(place(from), place(to ?? from)), kind),
  ).document.tree.text;
}

void main() {
  group('a box', () {
    test('goes on items that have none, and off where all have one', () {
      expect(
        _framed('- a\n- [x] b', FrameKind.checkbox, 0, 1),
        '- [ ] a\n- [x] b',
      );
      expect(_framed('- [ ] a\n- [x] b', FrameKind.checkbox, 0, 1), '- a\n- b');
    });

    test('makes text a list of boxes', () {
      expect(_framed('a\n\nb', FrameKind.checkbox, 0, 1), '- [ ] a\n- [ ] b');
    });
  });

  group('bullet or numbered', () {
    test('changes the whole list', () {
      expect(_framed('- a\n- b', FrameKind.numbered, 1), '1. a\n2. b');
    });

    test('of the list\'s own kind takes the items out of it', () {
      expect(
        _framed('1. a\n2. b\n3. c', FrameKind.numbered, 1),
        '1. a\n\nb\n\n3. c',
      );
    });

    test('of the list\'s own kind leaves an empty item\'s place', () {
      final document = ShownDocument(DocumentTree.read('1. a\n2.\n3. b'));
      final caret = TextSelection.caret(
        Place((document.rows[1] as TextRow).slot, 0),
      );
      final edited = run(document, SetFrame(caret, FrameKind.numbered));
      expect(edited.document.tree.text, '1. a\n\n3) b');
      final at = (edited.selection as TextSelection).extent;
      expect(edited.document.rowOf(at.slot), 1);
    });

    test('of the list\'s own kind keeps what an item\'s place shows', () {
      final tree = DocumentTree.read('1. a\n2.');
      final item = (tree.root.children.single as ListBlock).items.last;
      final document = ShownDocument(
        tree,
        tails: {
          ItemSlot(item.id): VisibleText([TextPiece(' ')]),
        },
      );
      final caret = TextSelection.caret(Place(ItemSlot(item.id), 1));
      final edited = run(document, SetFrame(caret, FrameKind.numbered));
      final at = (edited.selection as TextSelection).extent;
      expect(edited.document.textOf(at.slot).text, ' ');
      expect(at.offset, 1);
    });

    test('makes text items, joining a list of its kind', () {
      expect(_framed('a', FrameKind.bullet), '- a');
      expect(_framed('- a\n\nb', FrameKind.bullet, 1), '- a\n- b');
      expect(
        _framed('a\n\n- b\n\nc', FrameKind.bullet, 0, 2),
        '- a\n- b\n- c',
        reason: 'a list takes text on both sides',
      );
    });
  });

  group('a quote', () {
    test('wraps blocks, and goes off where all are quoted', () {
      expect(_framed('a\n\nb', FrameKind.quote, 0, 1), '> a\n>\n> b');
      expect(_framed('> a\n>\n> b', FrameKind.quote, 0), 'a\n\n> b');
    });

    test('in a list wraps the items\' text', () {
      expect(_framed('- a\n  - b', FrameKind.quote), '- > a\n  - b');
    });
  });
}
