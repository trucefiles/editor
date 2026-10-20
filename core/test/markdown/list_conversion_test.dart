import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import 'markdown_lines_support.dart';

/// Turning lines into list items and back, as a list button does.
void main() {
  String converted(String text, List<String> lines, ListKind kind) {
    final doc = MarkdownLines.parse(text);
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
    final doc = MarkdownLines.parse('a\n\nb');

    final (lists, added) = doc.toList([doc.lines[1].id], ListKind.checkbox);

    expect(lists.text, 'a\n- [ ] \nb');
    expect(added, isNull);
  });

  test('blank lines among others stay blank', () {
    final doc = MarkdownLines.parse('a\n\nb');

    expect(
      doc.toList([for (final l in doc.lines) l.id], ListKind.bullet).$1.text,
      '- a\n\n- b',
    );
  });

  test('a list with gaps goes back to text', () {
    final doc = MarkdownLines.parse('- a\n\n- b');

    expect(
      doc.toList([for (final l in doc.lines) l.id], ListKind.bullet).$1.text,
      'a\n\nb',
    );
  });

  test('below a heading or quote, adds an item, leaving them as they are', () {
    expect(converted('# a\nb', ['# a'], ListKind.bullet), '# a\n- \nb');
    expect(converted('> a', ['> a'], ListKind.bullet), '> a\n- ');
  });

  test('in a code block, adds an item at the end instead', () {
    final code = MarkdownLines.parse('```\ncode\n```');
    expect(
      code.toList([code.lines[1].id], ListKind.checkbox).$1.text,
      '```\ncode\n```\n- [ ] ',
    );
  });

  test('without lines, adds an item at the end before the final break', () {
    final doc = MarkdownLines.parse('a\n');

    final (added, id) = doc.toList(const [], ListKind.checkbox);

    expect(added.text, 'a\n- [ ] \n');
    expect(added.lines[1].id, id);
    expect(
      MarkdownLines.parse('a').toList(const [], ListKind.bullet).$1.text,
      'a\n- ',
    );
  });

  test('in an empty note, as its first line', () {
    expect(
      MarkdownLines.parse('').toList(const [], ListKind.numbered).$1.text,
      '1. ',
    );
  });
}
