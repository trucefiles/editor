import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import 'markdown_lines_support.dart';

/// Reading a document's lines, and editing and removing its items.
void main() {
  test('round-trips the text unchanged', () {
    expect(MarkdownLines.parse(doc).text, doc);
  });

  test('reads checkboxes in all bullet and mark styles', () {
    final list = MarkdownLines.parse(
      '* [ ] a\n+ [X] b\n- [x] c\n- no box\n1. [ ] d',
    );

    expect(list.lines.map((line) => line.isCheckbox), [
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

  test('a bulleted link is a bullet, not a checkbox', () {
    final list = MarkdownLines.parse('- [x](https://example.com)\n- [ ][ref]');

    expect(list.lines.map((line) => line.listKind), [
      ListKind.bullet,
      ListKind.bullet,
    ]);
  });

  test('reads bullets and numbered items, but no thematic break', () {
    final list = MarkdownLines.parse(
      '- a\n* b\n+\n1. c\n2) d\n---\n* * *\n-text\n1.text',
    );

    expect(list.lines.map((line) => line.listKind), [
      ListKind.bullet,
      ListKind.bullet,
      ListKind.bullet,
      ListKind.numbered,
      ListKind.numbered,
      null,
      null,
      null,
      null,
    ]);
    expect(list.lines.map((line) => line.text).take(5), [
      'a',
      'b',
      '',
      'c',
      'd',
    ]);
  });

  test('lines in code blocks are no items', () {
    final list = MarkdownLines.parse('```\n- [ ] a\n```\n- [ ] b');

    expect(list.lines.map(list.isItem), [false, false, false, true]);
    expect(list.lists, hasLength(1));
  });

  test('hasCheckboxes only with checkbox items', () {
    expect(MarkdownLines.parse(doc).hasCheckboxes, isTrue);
    expect(MarkdownLines.parse('# Title\n- text').hasCheckboxes, isFalse);
  });

  test('toggle changes only the mark', () {
    final list = MarkdownLines.parse('* [X] a\n- [ ] b');

    final toggled = list.toggle(idOf(list, 'a')).toggle(idOf(list, 'b'));

    expect(toggled.text, '* [ ] a\n- [x] b');
  });

  test('withText keeps the prefix', () {
    final line = MarkdownLines.parse('  +  [ ] a').lines.single;

    expect(line.withText('b').raw, '  +  [ ] b');
    expect(MarkdownLine.parse(line.id, ' 3)  a').withText('b').raw, ' 3)  b');
  });

  test('withText keeps a tab after the box', () {
    final line = MarkdownLines.parse('- [ ]\tfoo').lines.single;

    expect(line.withText('foox').raw, '- [ ]\tfoox');
  });

  test('a checkbox needs whitespace after the box', () {
    final list = MarkdownLines.parse('- [ ]tight\n- [x]: def\n- [ ]');

    expect(list.lines.map((line) => line.isCheckbox), [false, false, true]);
  });

  test('withText separates the first text of an empty item', () {
    final list = MarkdownLines.parse('- [ ]\n-');

    expect(list.lines.map((line) => line.withText('a').raw), [
      '- [ ] a',
      '- a',
    ]);
  });

  test('item text with line breaks stays one item', () {
    final line = MarkdownLines.parse('- [ ] a').lines.single;

    final edited = line.withText('b\r\nc\rd\u2028e');

    expect(edited.raw, '- [ ] b c d e');
    expect(edited.isCheckbox, isTrue);
  });

  test('withKind keeps the indent and bullet character', () {
    final line = MarkdownLines.parse('  * [x] a').lines.single;

    expect(line.withKind(ListKind.bullet, 'b').raw, '  * b');
    expect(line.withKind(ListKind.numbered, 'b').raw, '  1. b');
    expect(
      line.withKind(ListKind.bullet, 'b').withKind(ListKind.checkbox, 'c').raw,
      '  * [ ] c',
    );
  });

  test('ids survive edits', () {
    final list = MarkdownLines.parse(doc);
    final id = idOf(list, 'milk');

    final edited = list
        .withBlock(
          id,
          const ItemBlock(kind: ListKind.checkbox, depth: 0, text: 'oat'),
        )
        .toggle(id);

    expect(edited.lines[1].id, id);
  });

  test('removeLine keeps the subitems in place', () {
    final list = MarkdownLines.parse('- [ ] a\n- [ ] \n  - [ ] c');

    expect(list.removeLine(idOf(list, '')).text, '- [ ] a\n  - [ ] c');
  });

  test('remove takes the subitems along', () {
    final list = MarkdownLines.parse(doc);

    expect(
      list.remove(idOf(list, 'eggs')).text,
      '# Shopping\n- [ ] milk\nnote\n',
    );
  });

  test('reparse gives ids that never repeat earlier ones', () {
    final list = MarkdownLines.parse('- [ ] a\n- [ ] b');
    final (added, newId) = list.addItem(
      ListKind.checkbox,
      anchor: idOf(list, 'b'),
      before: false,
    );

    final reparsed = added.reparse('- [ ] x');

    final oldIds = {...added.lines.map((line) => line.id), newId};
    expect(reparsed.lines.single.id, isNot(isIn(oldIds)));
    expect(reparsed.text, '- [ ] x');
  });

  test('clearDone removes checked items and their subitems', () {
    expect(
      MarkdownLines.parse(doc).clearDone().text,
      '# Shopping\n- [ ] milk\nnote\n',
    );
  });

  test('doneIds holds checked items and their subitems', () {
    final list = MarkdownLines.parse(doc);

    expect(list.doneIds, {idOf(list, 'eggs'), idOf(list, 'large')});
  });

  test('an empty line ends a block', () {
    final list = MarkdownLines.parse('- [x] a\n\n  indented text');

    expect(list.clearDone().text, '\n  indented text');
  });
}
