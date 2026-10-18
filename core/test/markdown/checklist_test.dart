import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Id of the first line whose text is [text].
int idOf(Checklist list, String text) =>
    list.lines.firstWhere((line) => line.text == text).id;

void main() {
  const doc = '# Shopping\n- [ ] milk\n- [x] eggs\n  - [ ] large\nnote\n';

  test('round-trips the text unchanged', () {
    expect(Checklist.parse(doc).text, doc);
  });

  test('reads items in all bullet and mark styles', () {
    final list = Checklist.parse(
      '* [ ] a\n+ [X] b\n- [x] c\n- no box\n1. [ ] d',
    );

    expect(list.lines.map((line) => line.isItem), [
      true,
      true,
      true,
      false,
      false,
    ]);
    expect(list.lines.map((line) => line.isChecked), [
      false,
      true,
      true,
      false,
      false,
    ]);
  });

  test('a bulleted link is no item', () {
    final list = Checklist.parse('- [x](https://example.com)\n- [ ][ref]');

    expect(list.lines.map((line) => line.isItem), [false, false]);
  });

  test('hasItems only with checkbox items', () {
    expect(Checklist.parse(doc).hasItems, isTrue);
    expect(Checklist.parse('# Title\ntext').hasItems, isFalse);
  });

  test('toggle changes only the mark', () {
    final list = Checklist.parse('* [X] a\n- [ ] b');

    final toggled = list.toggle(idOf(list, 'a')).toggle(idOf(list, 'b'));

    expect(toggled.text, '* [ ] a\n- [x] b');
  });

  test('setText keeps the prefix', () {
    final list = Checklist.parse('  +  [ ] a');

    expect(list.setText(idOf(list, 'a'), 'b').text, '  +  [ ] b');
  });

  test('setText keeps a tab after the box', () {
    final list = Checklist.parse('- [ ]\tfoo');

    expect(list.setText(list.lines.single.id, 'foox').text, '- [ ]\tfoox');
  });

  test('an item needs whitespace after the box', () {
    final list = Checklist.parse('- [ ]tight\n- [x]: def\n- [ ]');

    expect(list.lines.map((line) => line.isItem), [false, false, true]);
  });

  test('setText separates the first text of an empty item', () {
    final list = Checklist.parse('- [ ]');

    expect(list.setText(list.lines.single.id, 'a').text, '- [ ] a');
  });

  test('item text with line breaks stays one item', () {
    final list = Checklist.parse('- [ ] a');
    final id = idOf(list, 'a');

    final edited = list.setText(id, 'b\r\nc\rd\u2028e');

    expect(edited.text, '- [ ] b c d e');
    expect(edited.lines.single.isItem, isTrue);
  });

  test('ids survive edits', () {
    final list = Checklist.parse(doc);
    final id = idOf(list, 'milk');

    final edited = list.setText(id, 'oat milk').toggle(id);

    expect(edited.lines[1].id, id);
  });

  group('insertAfter', () {
    test('adds a sibling after the subitems', () {
      final list = Checklist.parse(doc);

      final (added, id) = list.insertAfter(idOf(list, 'eggs'), 'bread');

      expect(
        added.text,
        '# Shopping\n- [ ] milk\n- [x] eggs\n  - [ ] large\n- [ ] bread\nnote\n',
      );
      expect(added.lines[4].id, id);
    });

    test('uses the bullet style and level of the item', () {
      final list = Checklist.parse('  * [x] a');

      final (added, _) = list.insertAfter(idOf(list, 'a'), 'b');

      expect(added.text, '  * [x] a\n  * [ ] b');
    });

    test('new ids are unique', () {
      final list = Checklist.parse('- [ ] a');
      final (once, first) = list.append('b');
      final (twice, second) = once.append('c');

      expect(first, isNot(second));
      expect(twice.lines.map((line) => line.id).toSet(), hasLength(3));
    });
  });

  group('append', () {
    test('goes after the last item', () {
      final list = Checklist.parse(doc);

      expect(
        list.append('bread').$1.text,
        '# Shopping\n- [ ] milk\n- [x] eggs\n  - [ ] large\n- [ ] bread\nnote\n',
      );
    });

    test('goes before the final line break if there are no items', () {
      expect(
        Checklist.parse('# Title\n').append('a').$1.text,
        '# Title\n- [ ] a\n',
      );
    });

    test('goes first in an empty document', () {
      expect(Checklist.parse('').append('a').$1.text, '- [ ] a\n');
    });
  });

  group('appendAfter', () {
    test('goes after the item and its subitems, at the margin', () {
      final list = Checklist.parse(doc);

      expect(
        list.appendAfter(idOf(list, 'milk'), 'bread').$1.text,
        '# Shopping\n- [ ] milk\n- [ ] bread\n- [x] eggs\n  - [ ] large\nnote\n',
      );
    });

    test('after a subitem, goes after the item it is under', () {
      final list = Checklist.parse(
        '- [ ] a\n  - [ ] b\n    - [ ] c\n  - [x] d',
      );

      expect(
        list.appendAfter(idOf(list, 'c'), 'e').$1.text,
        '- [ ] a\n  - [ ] b\n    - [ ] c\n  - [x] d\n- [ ] e',
      );
    });

    test('keeps the bullet style of the item', () {
      final list = Checklist.parse('* [x] a\ntext');

      expect(
        list.appendAfter(idOf(list, 'a'), 'b').$1.text,
        '* [x] a\n* [ ] b\ntext',
      );
    });
  });

  group('insertBefore', () {
    test('goes before the item, at its level', () {
      final list = Checklist.parse('# Shopping\n  * [x] milk\n- [ ] eggs\n');

      expect(
        list.insertBefore(idOf(list, 'milk'), 'bread').$1.text,
        '# Shopping\n  * [ ] bread\n  * [x] milk\n- [ ] eggs\n',
      );
    });

    test('never takes the items below as its subitems', () {
      final list = Checklist.parse('Groceries:\n  - [ ] milk\n  - [ ] eggs');

      final (added, id) = list.insertBefore(idOf(list, 'milk'), 'bread');

      expect(added.toggle(id).clearDone().text, list.text);
    });
  });

  test('removeLine keeps the subitems in place', () {
    final list = Checklist.parse('- [ ] a\n- [ ] \n  - [ ] c');

    expect(list.removeLine(idOf(list, '')).text, '- [ ] a\n  - [ ] c');
  });

  group('join', () {
    test("appends the item's text to the other and removes its line", () {
      final list = Checklist.parse('- [ ] milk\n- [x] eggs\nnote');

      expect(
        list.join(idOf(list, 'eggs'), into: idOf(list, 'milk')).text,
        '- [ ] milkeggs\nnote',
      );
    });

    test('joins into the item below, e.g. to drop an empty item', () {
      final list = Checklist.parse('- [ ] \n- [x] eggs');

      expect(
        list.join(idOf(list, ''), into: idOf(list, 'eggs')).text,
        '- [x] eggs',
      );
    });

    test('keeps the subitems of the removed item in place', () {
      final list = Checklist.parse('- [ ] a\n- [ ] b\n  - [ ] c');

      expect(
        list.join(idOf(list, 'b'), into: idOf(list, 'a')).text,
        '- [ ] ab\n  - [ ] c',
      );
    });

    test('adds a space after a box at the end of the line', () {
      final list = Checklist.parse('- [ ]\n- [ ] b');

      expect(list.join(idOf(list, 'b'), into: idOf(list, '')).text, '- [ ] b');
    });
  });

  test('remove takes the subitems along', () {
    final list = Checklist.parse(doc);

    expect(
      list.remove(idOf(list, 'eggs')).text,
      '# Shopping\n- [ ] milk\nnote\n',
    );
  });

  group('move', () {
    test('moves the item with its subitems', () {
      final list = Checklist.parse(doc);

      final moved = list.move(idOf(list, 'eggs'), beforeId: idOf(list, 'milk'));

      expect(
        moved.text,
        '# Shopping\n- [x] eggs\n  - [ ] large\n- [ ] milk\nnote\n',
      );
    });

    test('takes indented text lines along, up to an empty line', () {
      final list = Checklist.parse('- [ ] a\n- [ ] b\n  note\n\n  stays');

      final moved = list.move(idOf(list, 'b'), beforeId: idOf(list, 'a'));

      expect(moved.text, '- [ ] b\n  note\n- [ ] a\n\n  stays');
    });

    test('to the end stays before the final line break', () {
      final list = Checklist.parse('- [ ] a\n- [ ] b\n');

      expect(
        list.move(idOf(list, 'a'), beforeId: null).text,
        '- [ ] b\n- [ ] a\n',
      );
    });

    test('into its own subitems does nothing', () {
      final list = Checklist.parse(doc);

      expect(
        list.move(idOf(list, 'eggs'), beforeId: idOf(list, 'large')).text,
        doc,
      );
    });
  });

  group('toggleAndSort', () {
    test('a checked item moves with its subitems below the last item', () {
      final list = Checklist.parse(
        '# T\n- [ ] a\n  - [ ] sub\n- [ ] b\n- [x] c\nnote\n',
      );

      expect(
        list.toggleAndSort(idOf(list, 'a')).text,
        '# T\n- [ ] b\n- [x] c\n- [x] a\n  - [ ] sub\nnote\n',
      );
    });

    test('an unchecked item moves below the last open item', () {
      final list = Checklist.parse('- [ ] a\n- [x] b\n- [x] c\n');

      expect(
        list.toggleAndSort(idOf(list, 'c')).text,
        '- [ ] a\n- [ ] c\n- [x] b\n',
      );
    });

    test('unchecked with no open item, it moves above the first item', () {
      final list = Checklist.parse('# T\n- [x] a\n- [x] b');

      expect(list.toggleAndSort(idOf(list, 'b')).text, '# T\n- [ ] b\n- [x] a');
    });

    test('already in place, only the mark changes', () {
      final list = Checklist.parse('- [ ] a\ntext\n- [ ] b\n');

      expect(
        list.toggleAndSort(idOf(list, 'b')).text,
        '- [ ] a\ntext\n- [x] b\n',
      );
      expect(Checklist.parse('- [x] a').toggleAndSort(0).text, '- [ ] a');
    });

    test('a subitem toggles in place', () {
      final list = Checklist.parse(
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
      final list = Checklist.parse('- [ ] a\n- [ ] b\n    - [ ] c\n- [ ] d');

      final indented = list.indent(idOf(list, 'b'));

      expect(indented.text, '- [ ] a\n    - [ ] b\n        - [ ] c\n- [ ] d');
    });

    test('indents indented text lines too', () {
      final list = Checklist.parse('- [ ] a\n- [ ] b\n  note');

      expect(list.indent(idOf(list, 'b')).text, '- [ ] a\n  - [ ] b\n    note');
    });

    test('needs an item above', () {
      final list = Checklist.parse('# T\n- [ ] a');

      expect(list.indent(idOf(list, 'a')).text, '# T\n- [ ] a');
    });

    test('goes at most one level below the item above', () {
      final list = Checklist.parse('- [ ] a\n  - [ ] b');

      expect(list.indent(idOf(list, 'b')).text, '- [ ] a\n  - [ ] b');
    });

    test('needs the line shown above to be an item', () {
      final list = Checklist.parse('- [ ] a\n## Later\n- [ ] b');

      expect(list.indent(idOf(list, 'b')).text, list.text);
    });

    test('skips hidden lines and moves the item above them', () {
      final list = Checklist.parse(
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
      final list = Checklist.parse(doc);

      expect(
        list.outdent(idOf(list, 'large')).text,
        '# Shopping\n- [ ] milk\n- [x] eggs\n- [ ] large\nnote\n',
      );
    });

    test('outdent keeps a tab-indented subitem under a space item', () {
      final list = Checklist.parse('  - [ ] a\n\t- [ ] b');

      expect(list.outdent(idOf(list, 'a')).text, '- [ ] a\n- [ ] b');
    });

    test('outdent at the margin does nothing', () {
      final list = Checklist.parse(doc);

      expect(list.outdent(idOf(list, 'milk')).text, doc);
    });

    test('depth counts levels', () {
      final list = Checklist.parse(doc);

      expect(list.depthOf(list.lines[3]), 1);
      expect(list.depthOf(list.lines[1]), 0);
    });
  });

  test('reparse gives ids that never repeat earlier ones', () {
    final list = Checklist.parse('- [ ] a\n- [ ] b');
    final (added, newId) = list.append('c');

    final reparsed = added.reparse('- [ ] x');

    final oldIds = {...added.lines.map((line) => line.id), newId};
    expect(reparsed.lines.single.id, isNot(isIn(oldIds)));
    expect(reparsed.text, '- [ ] x');
  });

  test('clearDone removes checked items and their subitems', () {
    expect(
      Checklist.parse(doc).clearDone().text,
      '# Shopping\n- [ ] milk\nnote\n',
    );
  });

  test('doneIds holds checked items and their subitems', () {
    final list = Checklist.parse(doc);

    expect(list.doneIds, {idOf(list, 'eggs'), idOf(list, 'large')});
  });

  test('an empty line ends a block', () {
    final list = Checklist.parse('- [x] a\n\n  indented text');

    expect(list.clearDone().text, '\n  indented text');
  });
}
