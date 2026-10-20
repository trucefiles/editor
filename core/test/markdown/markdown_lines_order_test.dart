import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import 'markdown_lines_support.dart';

/// Adding, moving, sorting and indenting checklist items.
void main() {
  group('addItem', () {
    test('after an item goes after its subitems, at the margin', () {
      final list = MarkdownLines.parse(doc);

      expect(
        list
            .addItem(
              ListKind.checkbox,
              anchor: idOf(list, 'milk'),
              before: false,
            )
            .$1
            .text,
        '# Shopping\n- [ ] milk\n- [ ] \n- [x] eggs\n  - [ ] large\n\nnote\n',
      );
    });

    test('after a subitem, goes after the item it is under', () {
      final list = MarkdownLines.parse(
        '- [ ] a\n  - [ ] b\n    - [ ] c\n  - [x] d',
      );

      expect(
        list
            .addItem(ListKind.checkbox, anchor: idOf(list, 'c'), before: false)
            .$1
            .text,
        '- [ ] a\n  - [ ] b\n    - [ ] c\n  - [x] d\n- [ ] ',
      );
    });

    test('keeps the bullet style of the item, in the kind asked for', () {
      final list = MarkdownLines.parse('* [x] a\n\ntext');
      final a = idOf(list, 'a');

      expect(
        [
          for (final kind in ListKind.values)
            list.addItem(kind, anchor: a, before: false).$1.text,
        ],
        [
          '* [x] a\n* [ ] \n\ntext',
          '* [x] a\n* \n\ntext',
          '* [x] a\n1. \n\ntext',
        ],
      );
    });

    test('a numbered item after one takes the next number', () {
      final list = MarkdownLines.parse('3) a');

      expect(
        list
            .addItem(ListKind.numbered, anchor: idOf(list, 'a'), before: false)
            .$1
            .text,
        '3) a\n4) ',
      );
    });

    test('before an item goes before it, at its level', () {
      final list = MarkdownLines.parse(
        '# Shopping\n  * [x] milk\n- [ ] eggs\n',
      );

      expect(
        list
            .addItem(
              ListKind.checkbox,
              anchor: idOf(list, 'milk'),
              before: true,
            )
            .$1
            .text,
        '# Shopping\n  * [ ] \n  * [x] milk\n- [ ] eggs\n',
      );
    });

    test('before never takes the items below as its subitems', () {
      final list = MarkdownLines.parse(
        'Groceries:\n  - [ ] milk\n  - [ ] eggs',
      );

      final (added, id) = list.addItem(
        ListKind.checkbox,
        anchor: idOf(list, 'milk'),
        before: true,
      );

      expect(added.toggle(id).clearDone().text, list.text);
    });

    test('new ids are unique', () {
      final list = MarkdownLines.parse('- [ ] a');
      final a = idOf(list, 'a');
      final (once, first) = list.addItem(
        ListKind.bullet,
        anchor: a,
        before: false,
      );
      final (twice, second) = once.addItem(
        ListKind.bullet,
        anchor: a,
        before: false,
      );

      expect(first, isNot(second));
      expect(twice.lines.map((line) => line.id).toSet(), hasLength(3));
    });
  });

  group('move', () {
    test('moves the item with its subitems', () {
      final list = MarkdownLines.parse(doc);

      final moved = list.move(idOf(list, 'eggs'), beforeId: idOf(list, 'milk'));

      expect(
        moved.text,
        '# Shopping\n- [x] eggs\n  - [ ] large\n- [ ] milk\n\nnote\n',
      );
    });

    test('takes the lines under it along, blank lines among them', () {
      final list = MarkdownLines.parse('- [ ] a\n- [ ] b\n  note\n\n  more');

      final moved = list.move(idOf(list, 'b'), beforeId: idOf(list, 'a'));

      expect(moved.text, '- [ ] b\n  note\n\n  more\n- [ ] a');
    });

    test('leaves blank lines after its last line in place', () {
      final list = MarkdownLines.parse('- [ ] a\n- [ ] b\n  note\n\ntext');

      final moved = list.move(idOf(list, 'b'), beforeId: idOf(list, 'a'));

      expect(moved.text, '- [ ] b\n  note\n- [ ] a\n\ntext');
    });

    test('to the end stays before the final line break', () {
      final list = MarkdownLines.parse('- [ ] a\n- [ ] b\n');

      expect(
        list.move(idOf(list, 'a'), beforeId: null).text,
        '- [ ] b\n- [ ] a\n',
      );
    });

    test('into its own subitems does nothing', () {
      final list = MarkdownLines.parse(doc);

      expect(
        list.move(idOf(list, 'eggs'), beforeId: idOf(list, 'large')).text,
        doc,
      );
    });
  });

  group('moveNextTo', () {
    test('above a line goes just before it', () {
      final list = MarkdownLines.parse(doc);

      expect(
        list
            .moveNextTo(
              idOf(list, 'milk'),
              target: idOf(list, 'eggs'),
              below: false,
            )
            .text,
        doc,
      );
      expect(
        list
            .moveNextTo(
              idOf(list, 'eggs'),
              target: idOf(list, 'milk'),
              below: false,
            )
            .text,
        '# Shopping\n- [x] eggs\n  - [ ] large\n- [ ] milk\n\nnote\n',
      );
    });

    test('below an item with subitems becomes the first of them', () {
      final list = MarkdownLines.parse(doc);

      expect(
        list
            .moveNextTo(
              idOf(list, 'milk'),
              target: idOf(list, 'eggs'),
              below: true,
            )
            .text,
        '# Shopping\n- [x] eggs\n  - [ ] milk\n  - [ ] large\n\nnote\n',
      );
    });

    test('below an item with subitems takes its own subitems along', () {
      final list = MarkdownLines.parse('- a\n  - x\n- b\n    - y\n');

      expect(
        list
            .moveNextTo(idOf(list, 'b'), target: idOf(list, 'a'), below: true)
            .text,
        '- a\n  - b\n      - y\n  - x\n',
      );
    });

    test('below a line without subitems goes after it and its text', () {
      final list = MarkdownLines.parse('- a\n  more\n- b\n- c\n');

      expect(
        list
            .moveNextTo(idOf(list, 'c'), target: idOf(list, 'a'), below: true)
            .text,
        '- a\n  more\n- c\n- b\n',
      );
    });

    test('below its own first subitem changes nothing', () {
      final list = MarkdownLines.parse('- a\n  - x\n');

      expect(
        list
            .moveNextTo(idOf(list, 'x'), target: idOf(list, 'a'), below: true)
            .text,
        '- a\n  - x\n',
      );
    });

    test('takes the level of the spot, never a parent of the items below', () {
      final list = MarkdownLines.parse('- a\n  - x\n  - y\n- b\n');

      expect(
        list
            .moveNextTo(idOf(list, 'b'), target: idOf(list, 'x'), below: false)
            .text,
        '- a\n  - b\n  - x\n  - y\n',
      );
      expect(
        list
            .moveNextTo(idOf(list, 'b'), target: idOf(list, 'x'), below: true)
            .text,
        '- a\n  - x\n  - b\n  - y\n',
      );
    });

    test('a subitem dropped by an item at the margin goes there', () {
      final list = MarkdownLines.parse('- a\n- b\n  - y\n    - z\n');

      expect(
        list
            .moveNextTo(idOf(list, 'y'), target: idOf(list, 'a'), below: false)
            .text,
        '- y\n  - z\n- a\n- b\n',
      );
    });

    test('a subitem indented with other characters keeps its level', () {
      final list = MarkdownLines.parse('- a\n- b\n   - y\n    - z\n\t- w');

      expect(
        list
            .moveNextTo(idOf(list, 'y'), target: idOf(list, 'a'), below: false)
            .text,
        '- y\n - z\n - w\n- a\n- b',
      );
    });
  });

  group('toggleAndSort', () {
    test('a checked item moves with its subitems below the last item', () {
      final list = MarkdownLines.parse(
        '# T\n- [ ] a\n  - [ ] sub\n- [ ] b\n- [x] c\n\nnote\n',
      );

      expect(
        list.toggleAndSort(idOf(list, 'a')).text,
        '# T\n- [ ] b\n- [x] c\n- [x] a\n  - [ ] sub\n\nnote\n',
      );
    });

    test('an unchecked item moves below the last open item', () {
      final list = MarkdownLines.parse('- [ ] a\n- [x] b\n- [x] c\n');

      expect(
        list.toggleAndSort(idOf(list, 'c')).text,
        '- [ ] a\n- [ ] c\n- [x] b\n',
      );
    });

    test('unchecked with no open item, it moves above the first item', () {
      final list = MarkdownLines.parse('# T\n- [x] a\n- [x] b');

      expect(list.toggleAndSort(idOf(list, 'b')).text, '# T\n- [ ] b\n- [x] a');
    });

    test('already in place, only the mark changes', () {
      final list = MarkdownLines.parse('- [ ] a\ntext\n- [ ] b\n');

      expect(
        list.toggleAndSort(idOf(list, 'b')).text,
        '- [ ] a\ntext\n- [x] b\n',
      );
      final single = MarkdownLines.parse('- [x] a');
      expect(single.toggleAndSort(idOf(single, 'a')).text, '- [ ] a');
    });

    test('also moves checked items left among the open ones', () {
      final list = MarkdownLines.parse('- [x] a\n- [ ] b\n- [ ] c\n');

      expect(
        list.toggleAndSort(idOf(list, 'b')).text,
        '- [ ] c\n- [x] a\n- [x] b\n',
      );
    });

    test('items stay in their own list, up to a heading or text', () {
      final list = MarkdownLines.parse(
        '# Today\n- [ ] a\n- [ ] b\n# Later\n- [ ] c\n\nnote\n- [x] d\n',
      );

      expect(
        list.toggleAndSort(idOf(list, 'a')).text,
        '# Today\n- [ ] b\n- [x] a\n# Later\n- [ ] c\n\nnote\n- [x] d\n',
      );
      expect(
        list.toggleAndSort(idOf(list, 'c')).text,
        '# Today\n- [ ] a\n- [ ] b\n# Later\n- [x] c\n\nnote\n- [x] d\n',
      );
    });

    test('blank lines keep a list together', () {
      final list = MarkdownLines.parse('- [ ] a\n\n- [ ] b\n');

      expect(list.toggleAndSort(idOf(list, 'a')).text, '\n- [ ] b\n- [x] a\n');
    });

    test('sortChecked moves all checked items below, in their order', () {
      final list = MarkdownLines.parse(
        '# T\n- [x] a\n  - [ ] sub\n- [ ] b\n- [x] c\n- [ ] d\n\nend',
      );

      expect(
        list.sortChecked().text,
        '# T\n- [ ] b\n- [ ] d\n- [x] a\n  - [ ] sub\n- [x] c\n\nend',
      );
    });

    test('a box that is no item, e.g. in a code block, stays put', () {
      final list = MarkdownLines.parse(
        '- [ ] a\n```\n- [ ] code\n```\n- [ ] b',
      );
      final code = list.lines[2].id;

      expect(list.sortToggled(code).text, list.text);
    });

    test('a subitem toggles in place', () {
      final list = MarkdownLines.parse(
        '- [ ] a\n  - [ ] sub\n  - [ ] two\n- [ ] b',
      );

      expect(
        list.toggleAndSort(idOf(list, 'sub')).text,
        '- [ ] a\n  - [x] sub\n  - [ ] two\n- [ ] b',
      );
    });
  });

  group('indent', () {
    test('indents the subitems too, in the file\'s unit', () {
      final list = MarkdownLines.parse(
        '- [ ] a\n- [ ] b\n    - [ ] c\n- [ ] d',
      );

      final indented = list.indent(idOf(list, 'b'));

      expect(indented.text, '- [ ] a\n    - [ ] b\n        - [ ] c\n- [ ] d');
    });

    test('indents indented text lines too', () {
      final list = MarkdownLines.parse('- [ ] a\n- [ ] b\n  note');

      expect(list.indent(idOf(list, 'b')).text, '- [ ] a\n  - [ ] b\n    note');
    });

    test('leaves blank lines among the subitems as they are', () {
      final list = MarkdownLines.parse('- a\n- b\n  - c\n\n  - d');

      expect(
        list.indent(idOf(list, 'b')).text,
        '- a\n  - b\n    - c\n\n    - d',
      );
    });

    test('needs an item above', () {
      final list = MarkdownLines.parse('# T\n- [ ] a');

      expect(list.indent(idOf(list, 'a')).text, '# T\n- [ ] a');
    });

    test('goes at most one level below the item above', () {
      final list = MarkdownLines.parse('- [ ] a\n  - [ ] b');

      expect(list.indent(idOf(list, 'b')).text, '- [ ] a\n  - [ ] b');
    });

    test('needs the line shown above to be an item', () {
      final list = MarkdownLines.parse('- [ ] a\n## Later\n- [ ] b');

      expect(list.indent(idOf(list, 'b')).text, list.text);
    });

    test('skips hidden lines and moves the item above them', () {
      final list = MarkdownLines.parse(
        '- [ ] a\n- [x] done\n  - [ ] sub\n- [ ] b\n  - [ ] c',
      );

      final indented = list.indent(idOf(list, 'b'), hidden: list.doneIds);

      expect(
        indented.text,
        '- [ ] a\n  - [ ] b\n    - [ ] c\n- [x] done\n  - [ ] sub',
      );
      expect(indented.doneIds, isNot(contains(idOf(list, 'b'))));
    });

    test('outdent reverses indent', () {
      final list = MarkdownLines.parse(doc);

      expect(
        list.outdent(idOf(list, 'large')).text,
        '# Shopping\n- [ ] milk\n- [x] eggs\n- [ ] large\n\nnote\n',
      );
    });

    test('outdent keeps a tab-indented subitem under a space item', () {
      final list = MarkdownLines.parse('- p\n  - [ ] a\n\t- [ ] b');

      expect(list.outdent(idOf(list, 'a')).text, '- p\n- [ ] a\n  - [ ] b');
    });

    test('outdent keeps the subitem\'s own indent after the new one', () {
      final list = MarkdownLines.parse('- p\n  - a\n  \t- b');

      expect(list.outdent(idOf(list, 'a')).text, '- p\n- a\n\t- b');
    });

    test('indent puts the unit right after the item\'s own indent', () {
      final list = MarkdownLines.parse('- a\n  - x\n- b\n\t- c');

      expect(list.indent(idOf(list, 'b')).text, '- a\n  - x\n  - b\n  \t- c');
    });

    test('text continued without indent lands one level under the item', () {
      final list = MarkdownLines.parse('- a\n  - b\nlazy');

      expect(list.outdent(idOf(list, 'b')).text, '- a\n- b\n  lazy');
    });

    test('text continued at the item\'s own indent lands under it', () {
      final list = MarkdownLines.parse('- a\n  - b\n  more');

      expect(list.outdent(idOf(list, 'b')).text, '- a\n- b\n  more');
    });

    test('outdent leaves blank lines as they are', () {
      final list = MarkdownLines.parse('- a\n  - b\n    - c\n    \n    - d');

      expect(
        list.outdent(idOf(list, 'b')).text,
        '- a\n- b\n  - c\n    \n  - d',
      );
    });

    test('outdent at the margin does nothing', () {
      final list = MarkdownLines.parse(doc);

      expect(list.outdent(idOf(list, 'milk')).text, doc);
    });

    test('depth counts levels', () {
      final list = MarkdownLines.parse(doc);

      expect(list.depthOf(list.lines[3]), 1);
      expect(list.depthOf(list.lines[1]), 0);
    });
  });
}
