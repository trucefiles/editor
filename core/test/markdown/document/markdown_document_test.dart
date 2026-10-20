import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../markdown_document_support.dart';

/// Reading a document's lines and items, and parsing a changed version
/// of it, e.g. after it changed elsewhere.
void main() {
  /// The item on each line, if one starts there.
  List<ItemBlock?> itemsOf(MarkdownDocument document) => [
    for (final line in document.lines) document.outline.itemOf(line.id),
  ];

  test('round-trips the text unchanged', () {
    expect(MarkdownDocument.parse(doc).text, doc);
  });

  test('reads checkboxes in all bullet and mark styles', () {
    final items = itemsOf(
      MarkdownDocument.parse('* [ ] a\n+ [X] b\n- [x] c\n- no box\n1. [ ] d'),
    );

    expect(items.map((item) => item!.checked), [
      false,
      true,
      true,
      null,
      false,
    ]);
    expect(items.map((item) => item!.isChecked), [
      false,
      true,
      true,
      false,
      false,
    ]);
  });

  test('a bulleted link is a bullet, not a checkbox', () {
    final document = MarkdownDocument.parse(
      '- [x](https://example.com)\n- [ ][ref]',
    );

    expect(itemsOf(document).map((item) => item!.kind), [
      ListKind.bullet,
      ListKind.bullet,
    ]);
  });

  test('a checkbox needs whitespace after the box', () {
    final document = MarkdownDocument.parse('- [ ]tight\n- [x]: def\n- [ ]');

    expect(itemsOf(document).map((item) => item!.kind), [
      ListKind.bullet,
      ListKind.bullet,
      ListKind.checkbox,
    ]);
  });

  test('reads bullets and numbered items, but no thematic break', () {
    final document = MarkdownDocument.parse(
      '- a\n* b\n+\n1. c\n2) d\n---\n* * *\n-text\n1.text',
    );

    expect(itemsOf(document).map((item) => item?.kind), [
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
    expect(
      [for (final line in document.lines.take(5)) contentOf(document, line.id)],
      ['a', 'b', '', 'c', 'd'],
    );
  });

  test('lines in code blocks are no items', () {
    final document = MarkdownDocument.parse('```\n- [ ] a\n```\n- [ ] b');

    expect(itemsOf(document).map((item) => item != null), [
      false,
      false,
      false,
      true,
    ]);
    expect(document.outline.items, hasLength(1));
  });

  test('a line\'s content starts past its item marker and box', () {
    final document = MarkdownDocument.parse('- [ ] a\ntext\n```\n- b\n```');

    expect(
      [
        for (final line in document.lines)
          document.leafOf(line.id).lineOf(line.id).contentStart,
      ],
      [6, 0, 0, 0, 0],
    );
  });

  test('hasCheckboxes only with checkbox items', () {
    expect(MarkdownDocument.parse(doc).hasCheckboxes, isTrue);
    expect(MarkdownDocument.parse('# Title\n- text').hasCheckboxes, isFalse);
  });

  test('ids survive edits', () {
    final document = MarkdownDocument.parse(doc);
    final id = idOf(document, 'milk');

    final edited = document
        .toList([id], ListKind.numbered)
        .$1
        .toList([id], ListKind.checkbox)
        .$1
        .toggle(id);

    expect(edited.lines[1].id, id);
    expect(edited.text, doc.replaceFirst('- [ ] milk', '- [x] milk'));
  });

  test('leafOf and leafById find the leaf of a line', () {
    final document = MarkdownDocument.parse('a\nb\n\n# c');
    final [a, b, _, c] = document.lines;

    expect(document.leafOf(b.id), same(document.leafOf(a.id)));
    expect(document.leafById(a.id), same(document.leafOf(a.id)));
    expect(document.leafById(b.id), isNull);
    expect(document.leafOf(c.id), isA<HeadingBlock>());
    expect(document.indexOf(c.id), 3);
  });

  group('reparse', () {
    test('unchanged lines at the start and end keep their ids', () {
      final document = MarkdownDocument.parse('a\nb\nc\nd');

      final changed = document.reparse('a\nB\nnew\nd');

      final before = [for (final l in document.lines) l.id];
      final after = [for (final l in changed.lines) l.id];
      expect(changed.text, 'a\nB\nnew\nd');
      expect(after.first, before.first);
      expect(after.last, before.last);
      expect(before, isNot(contains(after[1])));
      expect(before, isNot(contains(after[2])));
    });

    test('changed lines get ids never used before', () {
      final document = MarkdownDocument.parse('a');

      final once = document.reparse('b');
      final twice = once.reparse('c');

      expect(twice.lines.single.id, isNot(once.lines.single.id));
      expect(twice.lines.single.id, isNot(document.lines.single.id));
    });

    test('ids never repeat those edits handed out', () {
      final document = MarkdownDocument.parse('- [ ] a\n- [ ] b');
      final (added, newId) = document.addItem(
        ListKind.checkbox,
        anchor: idOf(document, 'b'),
        before: false,
      );

      final reparsed = added.reparse('- [ ] x');

      final oldIds = {...added.lines.map((line) => line.id), newId};
      expect(reparsed.lines.single.id, isNot(isIn(oldIds)));
      expect(reparsed.text, '- [ ] x');
    });

    test('a line is kept at most once', () {
      final document = MarkdownDocument.parse('a\na');

      final changed = document.reparse('a');

      expect(changed.lines, hasLength(1));
    });
  });
}
