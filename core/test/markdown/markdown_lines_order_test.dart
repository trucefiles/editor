import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import 'markdown_lines_support.dart';

/// Adding, moving, sorting and indenting checklist items.
void main() {
  group('insertAfter', () {
    test('adds a sibling after the subitems', () {
      final list = MarkdownLines.parse(doc);

      final (added, id) = list.insertAfter(idOf(list, 'eggs'), 'bread');

      expect(
        added.text,
        '# Shopping\n- [ ] milk\n- [x] eggs\n  - [ ] large\n- [ ] bread\nnote\n',
      );
      expect(added.lines[4].id, id);
    });

    test('uses the bullet style and level of the item', () {
      final list = MarkdownLines.parse('  * [x] a');

      final (added, _) = list.insertAfter(idOf(list, 'a'), 'b');

      expect(added.text, '  * [x] a\n  * [ ] b');
    });

    test('new ids are unique', () {
      final list = MarkdownLines.parse('- [ ] a');
      final (once, first) = list.append('b');
      final (twice, second) = once.append('c');

      expect(first, isNot(second));
      expect(twice.lines.map((line) => line.id).toSet(), hasLength(3));
    });
  });

  group('append', () {
    test('goes after the last item', () {
      final list = MarkdownLines.parse(doc);

      expect(
        list.append('bread').$1.text,
        '# Shopping\n- [ ] milk\n- [x] eggs\n  - [ ] large\n- [ ] bread\nnote\n',
      );
    });

    test('goes before the final line break if there are no items', () {
      expect(
        MarkdownLines.parse('# Title\n').append('a').$1.text,
        '# Title\n- [ ] a\n',
      );
    });

    test('goes first in an empty document', () {
      expect(MarkdownLines.parse('').append('a').$1.text, '- [ ] a\n');
    });
  });

  group('appendAfter', () {
    test('goes after the item and its subitems, at the margin', () {
      final list = MarkdownLines.parse(doc);

      expect(
        list.appendAfter(idOf(list, 'milk'), 'bread').$1.text,
        '# Shopping\n- [ ] milk\n- [ ] bread\n- [x] eggs\n  - [ ] large\nnote\n',
      );
    });

    test('after a subitem, goes after the item it is under', () {
      final list = MarkdownLines.parse(
        '- [ ] a\n  - [ ] b\n    - [ ] c\n  - [x] d',
      );

      expect(
        list.appendAfter(idOf(list, 'c'), 'e').$1.text,
        '- [ ] a\n  - [ ] b\n    - [ ] c\n  - [x] d\n- [ ] e',
      );
    });

    test('keeps the bullet style of the item', () {
      final list = MarkdownLines.parse('* [x] a\ntext');

      expect(
        list.appendAfter(idOf(list, 'a'), 'b').$1.text,
        '* [x] a\n* [ ] b\ntext',
      );
    });
  });

  group('insertBefore', () {
    test('goes before the item, at its level', () {
      final list = MarkdownLines.parse('# Shopping\n  * [x] milk\n- [ ] eggs\n');

      expect(
        list.insertBefore(idOf(list, 'milk'), 'bread').$1.text,
        '# Shopping\n  * [ ] bread\n  * [x] milk\n- [ ] eggs\n',
      );
    });

    test('never takes the items below as its subitems', () {
      final list = MarkdownLines.parse('Groceries:\n  - [ ] milk\n  - [ ] eggs');

      final (added, id) = list.insertBefore(idOf(list, 'milk'), 'bread');

      expect(added.toggle(id).clearDone().text, list.text);
    });
  });

  group('move', () {
    test('moves the item with its subitems', () {
      final list = MarkdownLines.parse(doc);

      final moved = list.move(idOf(list, 'eggs'), beforeId: idOf(list, 'milk'));

      expect(
        moved.text,
        '# Shopping\n- [x] eggs\n  - [ ] large\n- [ ] milk\nnote\n',
      );
    });

    test('takes indented text lines along, up to an empty line', () {
      final list = MarkdownLines.parse('- [ ] a\n- [ ] b\n  note\n\n  stays');

      final moved = list.move(idOf(list, 'b'), beforeId: idOf(list, 'a'));

      expect(moved.text, '- [ ] b\n  note\n- [ ] a\n\n  stays');
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

  group('toggleAndSort', () {
    test('a checked item moves with its subitems below the last item', () {
      final list = MarkdownLines.parse(
        '# T\n- [ ] a\n  - [ ] sub\n- [ ] b\n- [x] c\nnote\n',
      );

      expect(
        list.toggleAndSort(idOf(list, 'a')).text,
        '# T\n- [ ] b\n- [x] c\n- [x] a\n  - [ ] sub\nnote\n',
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
      expect(MarkdownLines.parse('- [x] a').toggleAndSort(0).text, '- [ ] a');
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
        '# Today\n- [ ] a\n- [ ] b\n# Later\n- [ ] c\nnote\n- [x] d\n',
      );

      expect(
        list.toggleAndSort(idOf(list, 'a')).text,
        '# Today\n- [ ] b\n- [x] a\n# Later\n- [ ] c\nnote\n- [x] d\n',
      );
      expect(
        list.toggleAndSort(idOf(list, 'c')).text,
        '# Today\n- [ ] a\n- [ ] b\n# Later\n- [x] c\nnote\n- [x] d\n',
      );
    });

    test('blank lines keep a list together', () {
      final list = MarkdownLines.parse('- [ ] a\n\n- [ ] b\n');

      expect(list.toggleAndSort(idOf(list, 'a')).text, '\n- [ ] b\n- [x] a\n');
    });

    test('sortChecked moves all checked items below, in their order', () {
      final list = MarkdownLines.parse(
        '# T\n- [x] a\n  - [ ] sub\n- [ ] b\n- [x] c\n- [ ] d\nend',
      );

      expect(
        list.sortChecked().text,
        '# T\n- [ ] b\n- [ ] d\n- [x] a\n  - [ ] sub\n- [x] c\nend',
      );
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
      final list = MarkdownLines.parse('- [ ] a\n- [ ] b\n    - [ ] c\n- [ ] d');

      final indented = list.indent(idOf(list, 'b'));

      expect(indented.text, '- [ ] a\n    - [ ] b\n        - [ ] c\n- [ ] d');
    });

    test('indents indented text lines too', () {
      final list = MarkdownLines.parse('- [ ] a\n- [ ] b\n  note');

      expect(list.indent(idOf(list, 'b')).text, '- [ ] a\n  - [ ] b\n    note');
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
        '# Shopping\n- [ ] milk\n- [x] eggs\n- [ ] large\nnote\n',
      );
    });

    test('outdent keeps a tab-indented subitem under a space item', () {
      final list = MarkdownLines.parse('  - [ ] a\n\t- [ ] b');

      expect(list.outdent(idOf(list, 'a')).text, '- [ ] a\n- [ ] b');
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
