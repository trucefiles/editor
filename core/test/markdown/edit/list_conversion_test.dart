import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../markdown_document_support.dart';

/// Turning lines into list items and back, as a list button does.
void main() {
  String converted(String text, List<String> lines, ListKind kind) {
    final doc = MarkdownDocument.parse(text);
    return doc.toList([for (final l in lines) idOf(doc, l)], kind).$1.text;
  }

  test('turns a text line into an item, others untouched', () {
    expect(
      converted('a\nmilk\nb', ['milk'], ListKind.checkbox),
      'a\n- [ ] milk\nb',
    );
    expect(converted('milk', ['milk'], ListKind.bullet), '- milk');
    expect(converted('milk', ['milk'], ListKind.numbered), '1. milk');
  });

  test('a numbered line that only continues text becomes an item', () {
    expect(
      converted('The year\n2024. was good', [
        '2024. was good',
      ], ListKind.numbered),
      'The year\n1. 2024. was good',
    );
  });

  test('turns several lines at once', () {
    expect(converted('a\nb\nc', ['a', 'b'], ListKind.bullet), '- a\n- b\nc');
  });

  test('changes the kind of items, keeping level, bullet and text', () {
    expect(converted('* a\n  * b', ['b'], ListKind.checkbox), '* a\n  * [ ] b');
    expect(converted('- [x] a', ['a'], ListKind.numbered), '1. a');
    expect(converted('3. a', ['a'], ListKind.bullet), '- a');
  });

  test('turns items of the kind back into text', () {
    expect(
      converted('- [x] a\n- [ ] b', ['a', 'b'], ListKind.checkbox),
      'a\nb',
    );
    expect(converted('  1. a', ['a'], ListKind.numbered), 'a');
  });

  test('mixed lines all become the kind', () {
    expect(
      converted('- [ ] a\nb', ['a', 'b'], ListKind.checkbox),
      '- [ ] a\n- [ ] b',
    );
  });

  test('a blank line becomes an empty item', () {
    final doc = MarkdownDocument.parse('a\n\nb');

    final (lists, added) = doc.toList([doc.lines[1].id], ListKind.checkbox);

    expect(lists.text, 'a\n- [ ] \nb');
    expect(added, isNull);
  });

  test('blank lines among others stay blank', () {
    final doc = MarkdownDocument.parse('a\n\nb');

    expect(
      doc.toList([for (final l in doc.lines) l.id], ListKind.bullet).$1.text,
      '- a\n\n- b',
    );
  });

  test('a list with gaps goes back to text', () {
    final doc = MarkdownDocument.parse('- a\n\n- b');

    expect(
      doc.toList([for (final l in doc.lines) l.id], ListKind.bullet).$1.text,
      'a\n\nb',
    );
  });

  test('below a heading or rule, adds an item, leaving them as they are', () {
    expect(converted('# a\nb', ['# a'], ListKind.bullet), '# a\n- \nb');
    expect(converted('a\n\n---', ['---'], ListKind.bullet), 'a\n\n---\n- ');
  });

  test('keeps the indent and bullet character when the kind changes', () {
    const text = '- x\n  * [x] a';
    expect(converted(text, ['a'], ListKind.bullet), '- x\n  * a');
    expect(converted(text, ['a'], ListKind.numbered), '- x\n  1. a');
    final bullet = MarkdownDocument.parse(
      converted(text, ['a'], ListKind.bullet),
    );
    expect(
      bullet.toList([idOf(bullet, 'a')], ListKind.checkbox).$1.text,
      '- x\n  * [ ] a',
    );
  });

  test('a numbered item takes the number it shows; others start at 1', () {
    expect(converted('3. a\n7. b', ['b'], ListKind.checkbox), '3. a\n- [ ] b');
    expect(converted('3. a\n7. [ ] b', ['b'], ListKind.numbered), '3. a\n4. b');
    expect(converted('3. a\n- b', ['b'], ListKind.numbered), '3. a\n1. b');
  });

  test('lines in an item move as far as its content', () {
    expect(converted('- a\n  more', ['a'], ListKind.numbered), '1. a\n   more');
    expect(converted('- a\nlazy', ['a'], ListKind.numbered), '1. a\nlazy');
  });

  test('converts text in a quote, keeping its marks', () {
    expect(converted('> a', ['a'], ListKind.bullet), '> - a');
    expect(
      converted('> - [ ] a\n>\n> b', ['a', 'b'], ListKind.checkbox),
      '> - [ ] a\n>\n> - [ ] b',
    );
    expect(converted('> > a', ['a'], ListKind.numbered), '> > 1. a');
    expect(converted('> - a', ['a'], ListKind.bullet), '> a');
  });

  test('keeps a quote in an item', () {
    expect(converted('- > a', ['a'], ListKind.bullet), '> a');
    expect(converted('- > a', ['a'], ListKind.checkbox), '- [ ] > a');
  });

  test("an item's text turns with its item, from any of its lines", () {
    expect(converted('- a\\\n  b', ['b'], ListKind.bullet), 'a\\\n  b');
    expect(converted('1. a\n   b', ['a', 'b'], ListKind.bullet), '- a\n   b');
  });

  test('text in an item becomes an item in no item', () {
    expect(
      converted('- a\n\n  text', ['text'], ListKind.bullet),
      '- a\n\n- text',
    );
    expect(
      converted('- a\n  - b\n\n    text', ['text'], ListKind.bullet),
      '- a\n  - b\n\n- text',
    );
  });

  test('text continuing an item lazily becomes an item beside it', () {
    expect(
      converted('> - [ ] a\n> b', ['b'], ListKind.checkbox),
      '> - [ ] a\n> - [ ] b',
    );
  });

  test('in a code block, adds an item at the end instead', () {
    final code = MarkdownDocument.parse('```\ncode\n```');
    expect(
      code.toList([code.lines[1].id], ListKind.checkbox).$1.text,
      '```\ncode\n```\n- [ ] ',
    );
  });

  test('without lines, adds an item at the end before the final break', () {
    final doc = MarkdownDocument.parse('a\n');

    final (added, id) = doc.toList(const [], ListKind.checkbox);

    expect(added.text, 'a\n- [ ] \n');
    expect(added.lines[1].id, id);
    expect(
      MarkdownDocument.parse('a').toList(const [], ListKind.bullet).$1.text,
      'a\n- ',
    );
  });

  test('in an empty note, as its first line', () {
    expect(
      MarkdownDocument.parse('').toList(const [], ListKind.numbered).$1.text,
      '1. ',
    );
  });
}
