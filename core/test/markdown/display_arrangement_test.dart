import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import 'markdown_lines_support.dart';

/// What an editor shows of a document, in which order.
void main() {
  /// [entries] as short strings: line texts, `Done n`, `+` (before) or
  /// `+after`, `table n` and `image url`.
  List<String> describe(MarkdownLines doc, List<DisplayEntry> entries) {
    String text(LineId id) => doc.lines.firstWhere((l) => l.id == id).text;
    return [
      for (final entry in entries)
        switch (entry) {
          LineEntry(:final id) => text(id),
          DoneHeadingEntry(:final count, :final collapsed) =>
            collapsed ? 'Done $count (collapsed)' : 'Done $count',
          AddItemEntry(:final anchor, :final before) =>
            before ? '+before ${text(anchor)}' : '+after ${text(anchor)}',
          TableEntry(:final ids) => 'table ${ids.length}',
          ImageEntry(:final url) => 'image $url',
        },
    ];
  }

  const list =
      '# Shop\n- [ ] milk\n- [x] eggs\n  - [ ] large\n- [ ] tea\n\nnote';

  test('by default, every line in file order', () {
    final doc = MarkdownLines.parse(list);

    expect(describe(doc, const Arrangement().of(doc)), [
      '# Shop',
      'milk',
      'eggs',
      'large',
      'tea',
      '',
      'note',
    ]);
  });

  test('a Done section moves checked items with subitems after the open', () {
    final doc = MarkdownLines.parse(list);

    expect(describe(doc, const Arrangement(doneSection: true).of(doc)), [
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
    final doc = MarkdownLines.parse(list);
    final arrangement = Arrangement(
      doneSection: true,
      collapsed: {idOf(doc, 'milk')},
    );

    expect(describe(doc, arrangement.of(doc)), [
      '# Shop',
      'milk',
      'tea',
      'Done 1 (collapsed)',
      '',
      'note',
    ]);
  });

  test('each checklist gets its own Done section and add button', () {
    final doc = MarkdownLines.parse(
      '- [x] a\n- [ ] b\n# Two\n- [ ] c\n- [x] d',
    );
    const arrangement = Arrangement(
      doneSection: true,
      addItems: AddItemPlace.bottom,
    );

    expect(describe(doc, arrangement.of(doc)), [
      'b',
      '+after b',
      'Done 1',
      'a',
      '# Two',
      'c',
      '+after c',
      'Done 1',
      'd',
    ]);
  });

  test('an add button at the top goes before the first open item', () {
    final doc = MarkdownLines.parse('- [x] a\n- [ ] b');
    const arrangement = Arrangement(
      doneSection: true,
      addItems: AddItemPlace.top,
    );

    expect(describe(doc, arrangement.of(doc)), [
      '+before b',
      'b',
      'Done 1',
      'a',
    ]);
  });

  test('without open items, the add button goes by the items', () {
    final doc = MarkdownLines.parse('- [x] a');

    expect(
      describe(
        doc,
        const Arrangement(
          doneSection: true,
          addItems: AddItemPlace.bottom,
        ).of(doc),
      ),
      ['+after a', 'Done 1', 'a'],
    );
  });

  test('tables and images are drawn unless shown raw', () {
    final doc = MarkdownLines.parse(
      'a\n| x | y |\n|---|---|\n| 1 | 2 |\n![cat](cat.png)\nb',
    );

    expect(describe(doc, const Arrangement(drawBlocks: true).of(doc)), [
      'a',
      'table 3',
      'image cat.png',
      'b',
    ]);
    final raw = Arrangement(drawBlocks: true, raw: {idOf(doc, '| x | y |')});
    expect(describe(doc, raw.of(doc)), [
      'a',
      '| x | y |',
      '|---|---|',
      '| 1 | 2 |',
      'image cat.png',
      'b',
    ]);
  });

  test('lines carry their kind', () {
    final doc = MarkdownLines.parse('```\n- [ ] code\n```\ntext');

    expect(
      [
        for (final entry in const Arrangement(doneSection: true).of(doc))
          (entry as LineEntry).kind,
      ],
      [LineKind.fence, LineKind.code, LineKind.fence, LineKind.plain],
    );
  });

  test('bullets, numbered items and checkboxes make one list', () {
    final doc = MarkdownLines.parse(
      '- [x] done\n- bullet\n1. first\n- [ ] open\n\nText\n- other',
    );

    expect(
      describe(
        doc,
        const Arrangement(
          doneSection: true,
          addItems: AddItemPlace.bottom,
        ).of(doc),
      ),
      [
        'bullet',
        'first',
        'open',
        '+after open',
        'Done 1',
        'done',
        '',
        'Text',
        'other',
        '+after other',
      ],
    );
  });
}
