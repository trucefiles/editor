import 'package:test/test.dart';
import 'package:truce_core/src/markdown/edit/item_edits.dart';
import 'package:truce_core/truce_core.dart';

import '../markdown_document_support.dart';

/// Indents as Markdown needs them: a line one level under an item starts
/// at least where the item's content does, in the file's own style.
void main() {
  /// [document] after [edit] of the item [item]; once changed, the item
  /// is still one, [shift] levels deeper.
  String shifted(
    MarkdownDocument document,
    String item,
    MarkdownDocument Function(LineId id) edit,
    int shift,
  ) {
    final id = idOf(document, item);
    final changed = edit(id);
    if (changed.text != document.text) {
      expect(changed.outline.itemOf(id), isNotNull, reason: changed.text);
      expect(
        changed.outline.lineDepth(id),
        document.outline.lineDepth(id) + shift,
        reason: changed.text,
      );
    }
    return changed.text;
  }

  String indented(String text, String item) {
    final doc = MarkdownDocument.parse(text);
    return shifted(doc, item, doc.indent, 1);
  }

  String outdented(String text, String item) {
    final doc = MarkdownDocument.parse(text);
    return shifted(doc, item, doc.outdent, -1);
  }

  group('a line under an item', () {
    /// What a new item one level under [item] adds to its indent, in a
    /// file whose other items are indented as in [file].
    String offset(String item, {String file = '- u\n  - v'}) {
      final document = MarkdownDocument.parse('$item\n\n---\n$file');
      final parent = document.outline.items.first;
      final (added, id) = document.insertItem(
        1,
        ItemStyle.of(ListKind.bullet),
        place: document.outline.placeAt(1, 1),
      );
      final indent = document.outline.partsOf(parent, parent.firstLine).indent;
      final raw = added.lineOf(id)!.raw;
      return raw.substring(indent.length, raw.length - '- '.length);
    }

    test('reaches the content after the marker and its spaces', () {
      expect(offset('- a'), '  ');
      expect(offset('* a'), '  ');
      expect(offset('1. a'), '   ');
      expect(offset('1) a'), '   ');
      expect(offset('10. a'), '    ');
      expect(offset('-   a'), '    ');
      expect(offset('1.  a'), '    ');
    });

    test('counts a box as content', () {
      expect(offset('- [ ] a'), '  ');
      expect(offset('- [x] a'), '  ');
      expect(offset('1. [ ] a'), '   ');
    });

    test('takes one space for none or more than four after the marker', () {
      expect(offset('-'), '  ');
      expect(offset('1.'), '   ');
      expect(offset('-      code'), '  ');
    });

    test('is measured from the item\'s own indent', () {
      expect(offset('   1. a'), '   ');
      expect(offset(' - a'), '  ');
    });

    test('keeps the file\'s unit where it reaches the content', () {
      expect(offset('- a', file: '- u\n    - v'), '    ');
      expect(offset('- a', file: '- u\n\t- v'), '\t');
      expect(offset('10. a', file: '- u\n\t- v'), '\t');
      expect(offset('1. a', file: '- u\n   - v'), '   ');
    });

    test('takes spaces where the unit is too short or reads as code', () {
      expect(offset('1. a'), '   ');
      expect(offset('100. a', file: '- u\n\t- v'), '     ');
      expect(offset('- a', file: '1.    u\n      - v'), '  ');
    });
  });

  group('indent', () {
    test('under a numbered item reaches its text', () {
      expect(indented('1. a\n2. b', 'b'), '1. a\n   1. b');
      expect(indented('1. a\n- b', 'b'), '1. a\n   - b');
      expect(indented('9. a\n10. b\n11. c', 'c'), '9. a\n10. b\n    1. c');
    });

    test('under a bullet or box takes the file\'s unit', () {
      expect(indented('- a\n- b', 'b'), '- a\n  - b');
      expect(indented('- [ ] a\n- [ ] b', 'b'), '- [ ] a\n  - [ ] b');
      expect(
        indented('- a\n- b\n- c\n    - d', 'b'),
        '- a\n    - b\n- c\n    - d',
      );
      expect(indented('- a\n- b\n- c\n\t- d', 'b'), '- a\n\t- b\n- c\n\t- d');
    });

    test("takes the file's unit only from items, not from code", () {
      expect(
        indented('- a\n  ```\n     - x\n  ```\n- b\n- c', 'c'),
        '- a\n  ```\n     - x\n  ```\n- b\n  - c',
      );
    });

    test('lines up with the items already under the item above', () {
      expect(indented('- a\n     - x\n- b', 'b'), '- a\n     - x\n     - b');
      expect(indented('1. a\n   - x\n2. b', 'b'), '1. a\n   - x\n   1. b');
    });

    test('takes the subitems along, at their level under it', () {
      expect(
        indented('1. a\n2. b\n   - c\n     more', 'b'),
        '1. a\n   1. b\n      - c\n        more',
      );
    });

    test('a nested item goes under its sibling above', () {
      expect(indented('- a\n  1. x\n  2. y', 'y'), '- a\n  1. x\n     1. y');
    });

    test('a numbered item starts its new list at 1, as below text it must', () {
      final doc = MarkdownDocument.parse('1. a\n2. b\n3. c');
      final b = idOf(doc, 'b');

      final indented = doc.indent(b);

      expect(indented.text, '1. a\n   1. b\n3. c');
      expect(indented.outline.numberOf(indented.outline.itemOf(b)!), 1);
      expect(indented.outdent(b).text, '1. a\n1. b\n3. c');
    });
  });

  group('outdent', () {
    test('goes beside the item it was under', () {
      expect(outdented('1. a\n   - b', 'b'), '1. a\n- b');
      expect(outdented('- a\n  - x\n      - b', 'b'), '- a\n  - x\n  - b');
      expect(outdented('- a\n\t- x\n\t\t- b', 'b'), '- a\n\t- x\n\t- b');
    });

    test('takes the subitems along, at their level under it', () {
      expect(outdented('1. a\n   1. b\n      - c', 'b'), '1. a\n1. b\n   - c');
    });

    test('an item at the top level stays, also an indented one', () {
      expect(outdented('- a\n- b', 'b'), '- a\n- b');
      expect(outdented('  - a\n  - b\n  - c', 'b'), '  - a\n  - b\n  - c');
    });

    test('reverses indent', () {
      for (final text in ['1. a\n1. b', '- a\n- b', '- [ ] a\n- [ ] b']) {
        final doc = MarkdownDocument.parse(text);
        final id = doc.lines[1].id;
        expect(doc.indent(id).outdent(id).text, text);
      }
    });
  });

  group('drop', () {
    String dropped(
      String text,
      String item,
      String target, {
      bool below = false,
    }) {
      final doc = MarkdownDocument.parse(text);
      return doc
          .moveNextTo(idOf(doc, item), target: idOf(doc, target), below: below)
          .text;
    }

    test('under a numbered item reaches its text', () {
      expect(
        dropped('1. a\n   - x\n- b', 'b', 'x', below: true),
        '1. a\n   - x\n   - b',
      );
      expect(
        dropped('- b\n10. a\n    1. x', 'b', 'x'),
        '10. a\n    - b\n    1. x',
      );
    });

    test('takes the subitems along, at their level under it', () {
      expect(
        dropped('1. a\n   - x\n- b\n  - c', 'b', 'x', below: true),
        '1. a\n   - x\n   - b\n     - c',
      );
    });

    test('beside an indented item at the top level lines up with it', () {
      expect(dropped('  - a\n- b', 'b', 'a'), '  - b\n  - a');
      expect(dropped('  - a\n- b', 'b', 'a', below: true), '  - a\n  - b');
    });
  });

  group('a new item', () {
    (String, String) added(String text, String anchor) {
      final doc = MarkdownDocument.parse(text);
      String add({required bool before}) => doc
          .addItem(ListKind.bullet, anchor: idOf(doc, anchor), before: before)
          .$1
          .text;
      return (add(before: true), add(before: false));
    }

    test('before an item lines up with it', () {
      expect(added('1. a\n   - b', 'b').$1, '1. a\n   - \n   - b');
      expect(added('  - a', 'a').$1, '  - \n  - a');
    });

    test('after a subitem joins the list at the top, in its style', () {
      expect(added('* a\n  - b', 'b').$2, '* a\n  - b\n* ');
      expect(added('  * a\n    - b', 'b').$2, '  * a\n    - b\n  * ');
    });

    test('lines up with the item it follows, also past a blank line', () {
      expect(added('   - a\n  - b', 'a').$2, '   - a\n   - \n  - b');
      expect(added('   - a\n\n  - b', 'a').$2, '   - a\n   - \n\n  - b');
    });
  });

  group('text that continues an item without indent', () {
    test('lands under a numbered item at its text when it moves', () {
      final doc = MarkdownDocument.parse('- x\n1. a\nmore');

      expect(
        doc
            .moveNextTo(idOf(doc, 'a'), target: idOf(doc, 'x'), below: false)
            .text,
        '1. a\n   more\n- x',
      );
    });

    test('lands under a bullet in the file\'s unit', () {
      expect(outdented('- a\n  - b\nmore', 'b'), '- a\n- b\n  more');
    });

    test('indented short of the item\'s text lands at its text', () {
      final doc = MarkdownDocument.parse('- x\n1. a\n  more');

      expect(
        doc
            .moveNextTo(idOf(doc, 'a'), target: idOf(doc, 'x'), below: false)
            .text,
        '1. a\n   more\n- x',
      );
    });
  });

  group('a new item at a level', () {
    String inserted(String text, int at, int depth) {
      final document = MarkdownDocument.parse(text);
      return document
          .insertItem(
            at,
            ItemStyle.of(ListKind.bullet),
            place: document.outline.placeAt(at, depth),
            text: 'x',
          )
          .$1
          .text;
    }

    test('added at the top level lines up with the list above', () {
      expect(inserted('  - a\n# h', 1, 0), '  - a\n  - x\n# h');
    });

    test('added below a numbered item reaches its text', () {
      expect(inserted('1. a', 1, 1), '1. a\n   - x');
    });
  });

  group('in a quote', () {
    test('indent and outdent keep the quote marks', () {
      const text = '> - a\n> - b\n>   more\n> - c';
      const nested = '> - a\n>   - b\n>     more\n> - c';

      expect(indented(text, 'b'), nested);
      expect(outdented(nested, 'b'), text);
    });

    test('in a quote in an item, the marks stay after the item\'s indent', () {
      expect(indented('- p\n  > - a\n  > - b', 'b'), '- p\n  > - a\n  >   - b');
    });

    test('in nested quotes, all marks stay', () {
      expect(indented('> > 1. a\n> > 2. b', 'b'), '> > 1. a\n> >    1. b');
    });

    test('a blank line in the item keeps its quote mark', () {
      expect(
        outdented('> - a\n>   - b\n>\n>     more', 'b'),
        '> - a\n> - b\n>\n>   more',
      );
    });

    test('a drop out of the quote takes the lines out of it', () {
      final document = MarkdownDocument.parse('- x\n\n> - a\n>   more');

      expect(
        document
            .moveNextTo(
              idOf(document, 'a'),
              target: idOf(document, 'x'),
              below: false,
            )
            .text,
        '- a\n  more\n- x\n',
      );
    });
  });

  group('indent nests under the item shown above', () {
    test('when the line above is text in that item', () {
      expect(indented('- a\n  more\n- b', 'b'), '- a\n  more\n  - b');
    });

    test('when the line above is in a subitem, under that subitem', () {
      expect(
        indented('- a\n  - x\n    more\n- b', 'b'),
        '- a\n  - x\n    more\n  - b',
      );
    });
  });
}
