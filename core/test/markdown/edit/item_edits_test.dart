import 'package:test/test.dart';
import 'package:truce_core/src/markdown/edit/item_edits.dart';
import 'package:truce_core/truce_core.dart';

import '../markdown_document_support.dart';

/// Toggling, adding and removing items, and editing their text.
void main() {
  group('toggle', () {
    test('changes only the mark', () {
      final document = MarkdownDocument.parse('* [X] a\n- [ ] b');

      final toggled = document
          .toggle(idOf(document, 'a'))
          .toggle(idOf(document, 'b'));

      expect(toggled.text, '* [ ] a\n- [x] b');
    });

    test('finds the box after a number, a tab or quote marks', () {
      String toggled(String text) {
        final document = MarkdownDocument.parse(text);
        return document.toggle(document.lines.last.id).text;
      }

      expect(toggled('12) [ ] a'), '12) [x] a');
      expect(toggled('-\t[x]\ta'), '-\t[ ]\ta');
      expect(toggled('> - [ ] a'), '> - [x] a');
      expect(toggled('- a\n  > 1. [x] b'), '- a\n  > 1. [ ] b');
      expect(toggled('- [ ]'), '- [x]');
    });

    test('boxMarkIndex is the character between the brackets', () {
      final document = MarkdownDocument.parse('> 10.  [ ] a');
      final item = document.outline.items.single;

      expect(boxMarkIndex(document.outline, item), 8);
    });
  });

  group('remove', () {
    test('takes the subitems along', () {
      final document = MarkdownDocument.parse(doc);

      expect(
        document.remove(idOf(document, 'eggs')).text,
        '# Shopping\n- [ ] milk\n\nnote\n',
      );
    });

    test('clearDone removes checked items and their subitems', () {
      expect(
        MarkdownDocument.parse(doc).clearDone().text,
        '# Shopping\n- [ ] milk\n\nnote\n',
      );
    });

    test('lines under an item after an empty line are still its own', () {
      final document = MarkdownDocument.parse(
        '- [x] a\n\n  indented text\n\ntext',
      );

      expect(document.clearDone().text, '\ntext');
    });

    test('a line at the margin ends an item', () {
      final document = MarkdownDocument.parse('- [x] a\n\ntext');

      expect(document.clearDone().text, '\ntext');
    });

    test('in a quote, removes only the item\'s lines', () {
      final document = MarkdownDocument.parse('> - [x] a\n>   - b\n> - [ ] c');

      expect(document.clearDone().text, '> - [ ] c');
    });
  });

  group('insertItem', () {
    /// [text] with an item [content] added at index [at], at [depth].
    String inserted(String text, int at, int depth, String content) {
      final document = MarkdownDocument.parse(text);
      return document
          .insertItem(
            at,
            ItemStyle.of(ListKind.bullet),
            place: document.outline.placeAt(at, depth),
            text: content,
          )
          .$1
          .text;
    }

    test('a deeper item lands beside the item above at its level', () {
      expect(
        inserted('- a\n  - x\n- b\n     - y', 4, 1, 'c'),
        '- a\n  - x\n- b\n     - y\n     - c',
      );
    });

    test('an item goes at most one level below the item above', () {
      const text = '- a\n  - x\n- b\n     - y';
      final added = MarkdownDocument.parse(inserted(text, 4, 3, 'c'));

      expect(added.text, '$text\n       - c');
      expect(depthOf(added, 'c'), 2);
    });

    test('added items nest under each other as asked', () {
      final once = inserted('- a', 1, 1, 'b');

      expect(inserted(once, 2, 2, 'c'), '- a\n  - b\n    - c');
    });

    test('in a quote, keeps the quote marks', () {
      expect(inserted('> - a', 1, 0, 'b'), '> - a\n> - b');
      expect(inserted('> - a', 1, 1, 'b'), '> - a\n>   - b');
      expect(inserted('> text', 1, 0, 'b'), '> text\n> - b');
    });

    test('returns the new line\'s id', () {
      final document = MarkdownDocument.parse('- a');

      final (added, id) = document.insertItem(
        1,
        ItemStyle.of(ListKind.checkbox),
        place: document.outline.placeAt(1, 0),
      );

      expect(added.lineOf(id)!.raw, '- [ ] ');
      expect(document.lineOf(id), isNull);
    });
  });

  group('ItemStyle', () {
    test('writes each kind with its bullet, number and delimiter', () {
      expect(
        [
          for (final kind in ListKind.values)
            ItemStyle.of(kind, bullet: '*', number: 3, delimiter: ')').marker,
        ],
        ['* [ ] ', '* ', '3) '],
      );
    });

    test('after an item takes its style and the next number', () {
      final document = MarkdownDocument.parse('4) a\n1) b\n\n+ c');
      final [a, b, c] = document.outline.items;
      ItemStyle after(ItemBlock item, ListKind kind) =>
          ItemStyle.after(document.outline, item, kind);

      expect(after(b, ListKind.numbered).marker, '6) ');
      expect(after(a, ListKind.bullet).marker, '- ');
      expect(after(c, ListKind.checkbox).marker, '+ [ ] ');
      expect(after(c, ListKind.numbered).marker, '1. ');
    });
  });

  group("an item's text, replaced as an editor does", () {
    /// [text] with the content of its line [content] replaced by
    /// [replacement].
    String retyped(String text, String content, String replacement) {
      final document = MarkdownDocument.parse(text);
      final view = LeafView.of(
        document,
        document.leafOf(idOf(document, content)),
      );
      return document
          .replaceText(
            (view: view, offset: 0),
            (view: view, offset: view.text.length),
            replacement,
          )
          .$1
          .text;
    }

    test('keeps the marker, its spaces and the box', () {
      expect(retyped('  +  [ ] a', 'a', 'b'), '  +  [ ] b');
      expect(retyped(' 3)  a', 'a', 'b'), ' 3)  b');
    });

    test('keeps a tab after the box', () {
      expect(retyped('- [ ]\tfoo', 'foo', 'foox'), '- [ ]\tfoox');
    });

    test('separates the first text of an empty item', () {
      expect(retyped('- [ ]', '', 'a'), '- [ ] a');
      expect(retyped('-', '', 'a'), '- a');
    });
  });
}
