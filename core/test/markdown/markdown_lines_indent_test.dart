import 'package:test/test.dart';
import 'package:truce_core/src/markdown/line_writer.dart';
import 'package:truce_core/src/markdown/outline.dart';
import 'package:truce_core/truce_core.dart';

import 'markdown_lines_support.dart';

/// Indents as Markdown needs them: a line one level under an item starts
/// at least where the item's content does, in the file's own style.
void main() {
  String indented(String text, String item) {
    final doc = MarkdownLines.parse(text);
    return doc.indent(idOf(doc, item)).text;
  }

  String outdented(String text, String item) {
    final doc = MarkdownLines.parse(text);
    return doc.outdent(idOf(doc, item)).text;
  }

  group('a line under an item', () {
    /// What a line under [item] adds to its indent, in a file whose
    /// items are indented by [unit].
    String offset(String item, [String unit = '  ']) {
      final parent = MarkdownLine.parse(const LineId(0), item);
      final writer = LineWriter.of([
        parent,
        MarkdownLine.parse(const LineId(1), '$unit- x'),
      ]);
      final child = MarkdownLine.parse(const LineId(2), '- y');
      final written = writer.placed([child], UnderItem(parent, 1)).single;
      return written.indent.substring(parent.indent.length);
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
      expect(offset('    1. a'), '   ');
      expect(offset('\t- a'), '  ');
    });

    test('keeps the file\'s unit where it reaches the content', () {
      expect(offset('- a', '    '), '    ');
      expect(offset('- a', '\t'), '\t');
      expect(offset('10. a', '\t'), '\t');
      expect(offset('1. a', '   '), '   ');
    });

    test('takes spaces where the unit is too short or reads as code', () {
      expect(offset('1. a', '  '), '   ');
      expect(offset('100. a', '\t'), '     ');
      expect(offset('- a', '      '), '  ');
    });
  });

  group('indent', () {
    test('under a numbered item reaches its text', () {
      expect(indented('1. a\n2. b', 'b'), '1. a\n   2. b');
      expect(indented('1. a\n- b', 'b'), '1. a\n   - b');
      expect(indented('9. a\n10. b\n11. c', 'c'), '9. a\n10. b\n    11. c');
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

    test('lines up with the items already under the item above', () {
      expect(indented('- a\n     - x\n- b', 'b'), '- a\n     - x\n     - b');
      expect(indented('1. a\n   - x\n2. b', 'b'), '1. a\n   - x\n   2. b');
    });

    test('takes the subitems along, at their level under it', () {
      expect(
        indented('1. a\n2. b\n   - c\n     more', 'b'),
        '1. a\n   2. b\n      - c\n        more',
      );
    });

    test('a nested item goes under its sibling above', () {
      expect(indented('- a\n  1. x\n  2. y', 'y'), '- a\n  1. x\n     2. y');
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
      for (final text in ['1. a\n2. b', '- a\n- b', '- [ ] a\n- [ ] b']) {
        final doc = MarkdownLines.parse(text);
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
      final doc = MarkdownLines.parse(text);
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
      final doc = MarkdownLines.parse(text);
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

    test('keeps the next item beside it, also past a blank line', () {
      expect(added('    - a\n  - b', 'a').$2, '    - a\n  - \n  - b');
      expect(added('    - a\n\n  - b', 'a').$2, '    - a\n  - \n\n  - b');
    });
  });

  group('text that continues an item without indent', () {
    test('lands under a numbered item at its text when it moves', () {
      final doc = MarkdownLines.parse('- x\n1. a\nmore');

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
  });

  group('a new item from blocks', () {
    test('typed under a numbered item reaches its text', () {
      final doc = MarkdownLines.parse('1. a\nb');
      final b = idOf(doc, 'b');

      final changed = doc.withBlock(
        b,
        const ItemBlock(
          kind: ListKind.bullet,
          checked: false,
          depth: 1,
          text: 'b',
        ),
      );

      expect(changed.text, '1. a\n   - b');
    });

    test('added at the top level lines up with the list above', () {
      final doc = MarkdownLines.parse('  - a\n# h');

      final (added, _) = doc.insertBlocks(
        const [
          ItemBlock(kind: ListKind.bullet, checked: false, depth: 0, text: 'x'),
        ],
        after: idOf(doc, 'a'),
        shownBelow: null,
      );

      expect(added.text, '  - a\n  - x\n# h');
    });

    test('added below a numbered item reaches its text', () {
      final doc = MarkdownLines.parse('1. a');

      final (added, _) = doc.insertBlocks(
        const [
          ItemBlock(kind: ListKind.bullet, checked: false, depth: 1, text: 'x'),
        ],
        after: idOf(doc, 'a'),
        shownBelow: null,
      );

      expect(added.text, '1. a\n   - x');
    });
  });
}
