import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// What an editor shows of a document, in which order.
void main() {
  /// What [arrangement] shows of [source], as short strings: a line as
  /// written, a leaf as its text, `Done n`, `+before`/`+after` and the
  /// text of its anchor item, `table n` for a table of n lines.
  List<String> describe(String source, Arrangement arrangement) {
    final document = MarkdownDocument.parse(source);
    String leaf(LineId id) => document.leafById(id)!.text;
    return [
      for (final entry in arrangement.of(document))
        switch (entry) {
          LineEntry(:final line) => document.lineOf(line)!.raw,
          LeafEntry(leaf: final id) => leaf(id),
          TableEntry(leaf: final id) =>
            'table ${document.leafById(id)!.lines.length}',
          DoneHeadingEntry(:final count, :final collapsed) =>
            collapsed ? 'Done $count (collapsed)' : 'Done $count',
          AddItemEntry(:final anchor, :final before) =>
            '${before ? '+before' : '+after'} ${leaf(anchor)}',
        },
    ];
  }

  const list =
      '# Shop\n- [ ] milk\n- [x] eggs\n  - [ ] large\n- [ ] tea\n\nnote';

  test('as lines, every line as written, in file order', () {
    expect(describe(list, const Arrangement.lines()), list.split('\n'));
  });

  test('as blocks, every leaf in file order', () {
    expect(describe(list, const Arrangement.blocks()), [
      '# Shop',
      'milk',
      'eggs',
      'large',
      'tea',
      '',
      'note',
    ]);
    expect(describe('a\nb\n\n> c\n> d', const Arrangement.blocks()), [
      'a\nb',
      '',
      'c\nd',
    ]);
  });

  test('a Done section moves checked items with subitems after the open', () {
    expect(describe(list, const Arrangement.blocks(doneSection: true)), [
      '# Shop',
      'milk',
      'tea',
      'Done 1',
      'eggs',
      'large',
      '',
      'note',
    ]);
  });

  test('a collapsed Done section hides its items', () {
    final document = MarkdownDocument.parse(list);
    final milk = document.lines[1].id;

    expect(
      describe(list, Arrangement.blocks(doneSection: true, collapsed: {milk})),
      ['# Shop', 'milk', 'tea', 'Done 1 (collapsed)', '', 'note'],
    );
  });

  test('each list gets its own Done section and add button', () {
    expect(
      describe(
        '- [x] a\n- [ ] b\n# Two\n- [ ] c\n- [x] d',
        const Arrangement.blocks(
          doneSection: true,
          addItems: AddItemPlace.bottom,
        ),
      ),
      ['b', '+after b', 'Done 1', 'a', '# Two', 'c', '+after c', 'Done 1', 'd'],
    );
  });

  test('items with other markers make lists of their own', () {
    expect(
      describe(
        '- [x] done\n- bullet\n1. first\n- [ ] open\n\nText\n- other',
        const Arrangement.blocks(
          doneSection: true,
          addItems: AddItemPlace.bottom,
        ),
      ),
      [
        'bullet',
        '+after bullet',
        'Done 1',
        'done',
        'first',
        '+after first',
        'open',
        '+after open',
        '',
        'Text',
        'other',
        '+after other',
      ],
    );
  });

  test('an add button at the top goes before the first open item', () {
    expect(
      describe(
        '- [x] a\n- [ ] b',
        const Arrangement.blocks(doneSection: true, addItems: AddItemPlace.top),
      ),
      ['+before b', 'b', 'Done 1', 'a'],
    );
  });

  test('without open items, the add button goes by the items', () {
    expect(
      describe(
        '- [x] a',
        const Arrangement.blocks(
          doneSection: true,
          addItems: AddItemPlace.bottom,
        ),
      ),
      ['+after a', 'Done 1', 'a'],
    );
  });

  test('lists in other blocks get no Done section or add button', () {
    expect(
      describe(
        '> - [x] a\n> - [ ] b',
        const Arrangement.blocks(
          doneSection: true,
          addItems: AddItemPlace.bottom,
        ),
      ),
      ['a', 'b'],
    );
  });

  test('tables are drawn unless shown as text', () {
    const source = 'a\n\n| x | y |\n|---|---|\n| 1 | 2 |\n\nb';
    final table = MarkdownDocument.parse(source).lines[2].id;

    expect(describe(source, const Arrangement.blocks()), [
      'a',
      '',
      'table 3',
      '',
      'b',
    ]);
    expect(describe(source, Arrangement.blocks(raw: {table})), [
      'a',
      '',
      '| x | y |\n|---|---|\n| 1 | 2 |',
      '',
      'b',
    ]);
  });

  test('a code block is one leaf, its lines no items', () {
    expect(describe('```\n- [ ] code\n```\ntext', const Arrangement.blocks()), [
      '```\n- [ ] code\n```',
      'text',
    ]);
  });
}
