import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import 'checklist_support.dart';

/// Reading a checklist, and editing, joining and removing its items.
void main() {
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
