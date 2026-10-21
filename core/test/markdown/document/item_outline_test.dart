import 'package:test/test.dart';
import 'package:truce_core/src/markdown/document/item_outline.dart';
import 'package:truce_core/truce_core.dart';

import '../markdown_document_support.dart';

/// The list items of a document and where lines go among them.
void main() {
  /// The item on the line at [index] of [document].
  ItemBlock itemAt(MarkdownDocument document, int index) =>
      document.outline.itemOf(document.lines[index].id)!;

  /// [item]'s lines, by index.
  LineSpan subtreeAt(MarkdownDocument document, int index) =>
      document.outline.subtree(itemAt(document, index));

  /// The indexes of the marker lines of the list the item at [index] is
  /// in.
  List<int> listAt(MarkdownDocument document, int index) => [
    for (final item in document.outline.listOf(itemAt(document, index)))
      document.indexOf(item.markerLine),
  ];

  /// What kind of leaf each line is in.
  List<Type> leafTypes(MarkdownDocument document) => [
    for (final line in document.lines) document.leafOf(line.id).runtimeType,
  ];

  bool isItem(MarkdownDocument document, int index) =>
      document.outline.itemOf(document.lines[index].id) != null;

  bool isInQuote(MarkdownDocument document, int index) => document
      .leafOf(document.lines[index].id)
      .ancestors
      .any((block) => block is QuoteBlock);

  test('items are in file order, nested ones after their item', () {
    final document = MarkdownDocument.parse('- a\n  - b\ntext\n\n1. c');

    expect(
      [
        for (final item in document.outline.items)
          contentOf(document, item.markerLine),
      ],
      ['a', 'b', 'c'],
    );
  });

  test('an item holds the deeper lines below, blank lines among them', () {
    final document = MarkdownDocument.parse(
      '- a\n  - b\n    text\n- c\n  - d\n\n  more\n\n- e',
    );
    expect(subtreeAt(document, 0), (start: 0, end: 3));
    expect(subtreeAt(document, 1), (start: 1, end: 3));
    expect(subtreeAt(document, 3), (start: 3, end: 7));
    expect(subtreeAt(document, 4), (start: 4, end: 5));
    expect(subtreeAt(document, 8), (start: 8, end: 9));
  });

  test("a line right below an item's text continues the item", () {
    final document = MarkdownDocument.parse('- a\ntext\n- b\n# H\n- c');
    expect(subtreeAt(document, 0), (start: 0, end: 2));
    expect(listAt(document, 2), [0, 2]);
    expect(listAt(document, 4), [4]);
  });

  test('lines in no item are at the top level', () {
    expect(depths(MarkdownDocument.parse('text\n  more\n- a')), [0, 0, 0]);
  });

  test('a code block stays under its item, whatever its lines hold', () {
    final document = MarkdownDocument.parse(
      '- a\n  ```\n  - code\n\n  ```\n- b',
    );
    expect(subtreeAt(document, 0), (start: 0, end: 5));
    expect(document.outline.lineDepth(document.lines[2].id), 1);
    expect(isItem(document, 2), isFalse);
  });

  test('a code line not indented to the item ends the item and the code', () {
    final document = MarkdownDocument.parse('- a\n  ```\ncode\n- b');
    expect(subtreeAt(document, 0), (start: 0, end: 2));
    expect(leafTypes(document), [
      ParagraphBlock,
      CodeBlock,
      ParagraphBlock,
      ParagraphBlock,
    ]);
    expect(isItem(document, 3), isTrue);
  });

  test('depth is the number of items a line is under', () {
    // `      - b` is four columns past a's content: code in it.
    final document = MarkdownDocument.parse(
      '- a\n      - b\n  - c\n        text',
    );
    expect(depths(document), [0, 1, 1, 2]);
    expect(isItem(document, 1), isFalse);
  });

  test('depthOf counts the items an item is in', () {
    final document = MarkdownDocument.parse('- a\n  - b\n    - c\n- d');
    expect(document.outline.items.map(document.outline.depthOf), [0, 1, 2, 0]);
  });

  test('itemsAt lists the items a line is in or starts, innermost first', () {
    final document = MarkdownDocument.parse('- a\n  - b\n    text\n- c');
    List<String> at(int index) => [
      for (final item in document.outline.itemsAt(document.lines[index].id))
        contentOf(document, item.markerLine),
    ];

    expect(
      [for (var i = 0; i < 4; i++) at(i)],
      [
        ['a'],
        ['b', 'a'],
        ['b', 'a'],
        ['c'],
      ],
    );
    expect(
      MarkdownDocument.parse('text').outline.itemsAt(const LineId(0)),
      isEmpty,
    );
  });

  test('a margin item is the top item a line is under', () {
    final document = MarkdownDocument.parse(
      '- a\n  - b\n    - c\n- d\n\ntext\n  - e',
    );
    expect(
      [
        for (final i in [0, 1, 2, 3, 6])
          document.indexOf(
            document.outline.marginItemOf(itemAt(document, i)).markerLine,
          ),
      ],
      [0, 0, 0, 3, 6],
    );
  });

  test('a list is a run of items at one level', () {
    final document = MarkdownDocument.parse(
      '- a\n\n  text\n- b\n  - x\n\n  y\n  - z\n# H\n- c',
    );
    expect(listAt(document, 0), [0, 3]);
    expect(listAt(document, 3), [0, 3]);
    expect(listAt(document, 4), [4]);
    expect(listAt(document, 7), [7]);
    expect(listAt(document, 9), [9]);
  });

  test('another bullet character or delimiter starts another list', () {
    final document = MarkdownDocument.parse('- a\n* b\n* [ ] c\n1. d\n2) e');
    expect(listAt(document, 0), [0]);
    expect(listAt(document, 1), [1, 2]);
    expect(listAt(document, 3), [3]);
    expect(listAt(document, 4), [4]);
  });

  test('checkbox and plain items with one bullet are one list', () {
    final document = MarkdownDocument.parse('- [ ] a\n- b\n- [x] c');
    expect(listAt(document, 1), [0, 1, 2]);
  });

  group('numberOf', () {
    List<int?> numbers(String text) {
      final document = MarkdownDocument.parse(text);
      return [
        for (final line in document.lines)
          switch (document.outline.itemOf(line.id)) {
            final item? => document.outline.numberOf(item),
            null => null,
          },
      ];
    }

    test('counts on from the first number, whatever the others say', () {
      expect(numbers('3. a\n1. b\n1. c'), [3, 4, 5]);
      expect(numbers('0. a\n7. b'), [0, 1]);
    });

    test('a line that is no item ends a numbered run', () {
      expect(numbers('1. a\n   1. x\n\n   y\n   1. z')[4], 1);
    });

    test('another delimiter starts the count anew', () {
      expect(numbers('1. a\n2. b\n5) c\n1) d'), [1, 2, 5, 6]);
    });

    test('numbers and depths are read per line', () {
      const text = '2. a\n   - x\n   4. y\n   1. z\n1. b';
      expect(numbers(text), [2, null, 4, 5, 3]);
      expect(depths(MarkdownDocument.parse(text)), [0, 1, 1, 1, 0]);
    });
  });

  test('doneIds holds checked items and their subitems', () {
    final document = MarkdownDocument.parse(doc);

    expect(document.outline.doneIds, {
      idOf(document, 'eggs'),
      idOf(document, 'large'),
    });
  });

  group('partsOf cuts a line of an item', () {
    /// Line [line] of [text], cut for its item number [item].
    ItemLineParts parts(String text, int item, int line) {
      final document = MarkdownDocument.parse(text);
      return document.outline.partsOf(
        document.outline.items[item],
        document.lines[line],
      );
    }

    test('into its indent and the rest from the marker on', () {
      expect(parts('- a', 0, 0), (
        outer: '',
        indent: '',
        rest: '- a',
        reaches: true,
      ));
      expect(parts('- a\n  - [ ] b', 1, 1), (
        outer: '',
        indent: '  ',
        rest: '- [ ] b',
        reaches: true,
      ));
    });

    test('a line in the item: its indent and its content', () {
      expect(parts('1. a\n   more', 0, 1), (
        outer: '',
        indent: '   ',
        rest: 'more',
        reaches: true,
      ));
    });

    test('text continuing the item lazily does not reach it', () {
      expect(parts('- a\nlazy', 0, 1), (
        outer: '',
        indent: '',
        rest: 'lazy',
        reaches: false,
      ));
    });

    test('quote marks the item is in are outer', () {
      expect(parts('> - a\n>   - b', 1, 1), (
        outer: '> ',
        indent: '  ',
        rest: '- b',
        reaches: true,
      ));
    });

    test('markers of items starting on the same line are indent', () {
      expect(parts('- - a', 1, 0), (
        outer: '',
        indent: '- ',
        rest: '- a',
        reaches: true,
      ));
    });

    test('a quote in the item is part of the rest', () {
      expect(parts('- a\n  > q', 0, 1), (
        outer: '',
        indent: '  ',
        rest: '> q',
        reaches: true,
      ));
    });
  });

  group('a line put at a level lands', () {
    String placed(String text, int index, int depth) {
      final document = MarkdownDocument.parse(text);
      String name(ItemBlock item) => contentOf(document, item.markerLine);
      return switch (document.outline.placeAt(index, depth)) {
        AtMargin(:final outer) => 'margin "$outer"',
        BesideItem(:final item) => 'beside ${name(item)}',
        UnderItem(:final item, :final depth) => 'under ${name(item)} $depth',
      };
    }

    test('beside the item below at that level, past blank lines', () {
      expect(placed('- a\n  - b', 1, 1), 'beside b');
      expect(placed('- a\n\n- b', 1, 0), 'beside b');
    });

    test('beside an item at that level above', () {
      expect(placed('- a\n  - b\n- c', 2, 1), 'beside b');
      expect(placed('  - a\n  - b', 2, 0), 'beside b');
    });

    test('at the margin at the top level, with no list above', () {
      expect(placed('text', 1, 0), 'margin ""');
      expect(placed('', 0, 0), 'margin ""');
    });

    test('under the deepest item above, as deep as it lets', () {
      expect(placed('- a', 1, 1), 'under a 1');
      expect(placed('- a', 1, 3), 'under a 1');
      expect(placed('- a\n  - b', 2, 3), 'under b 2');
    });

    test('at the margin for a deeper level with no item above', () {
      expect(placed('text', 1, 1), 'margin ""');
    });

    test('at the margin of the quote the line above is in', () {
      expect(placed('> text', 1, 0), 'margin "> "');
      expect(placed('> > text', 1, 0), 'margin "> > "');
    });

    test('beside or under items in a quote', () {
      expect(placed('> - a', 1, 0), 'beside a');
      expect(placed('> - a', 1, 1), 'under a 1');
    });
  });

  group('lines meet the open items first, then are read inside them', () {
    List<int> depthsOf(String text) => depths(MarkdownDocument.parse(text));
    LineSpan firstSubtree(String text) =>
        subtreeAt(MarkdownDocument.parse(text), 0);

    test("a line is in an item only if indented to the item's text", () {
      expect(depthsOf('1. a\n  - b'), [0, 0]);
      expect(depthsOf('- a\n - b'), [0, 0]);
      expect(depthsOf('1. a\n   - b'), [0, 1]);
      expect(firstSubtree('-   a\n\n  b'), (start: 0, end: 1));
      expect(firstSubtree('-\n\n  b'), (start: 0, end: 1));
      expect(firstSubtree('-\n  b'), (start: 0, end: 2));
      expect(firstSubtree('-   a\n\n    b'), (start: 0, end: 3));
    });

    test('a tab counts to the next tab stop', () {
      expect(depthsOf('- a\n \t- b'), [0, 1]);
      expect(depthsOf('1. a\n  \t- b'), [0, 1]);
    });

    test('a code fence is read from the content of a nested item', () {
      final document = MarkdownDocument.parse(
        '- a\n  - b\n    ```\n    - x\n    ```\n- c',
      );
      expect(leafTypes(document).sublist(2, 5), [
        CodeBlock,
        CodeBlock,
        CodeBlock,
      ]);
      expect(isItem(document, 3), isFalse);
      expect(document.outline.lineDepth(document.lines[3].id), 2);
      expect(isItem(document, 5), isTrue);
    });

    test('an unclosed fence in an item ends where the item ends', () {
      final document = MarkdownDocument.parse(
        '- [ ] a\n  ```\n- [ ] b\n- [ ] c',
      );
      expect(leafTypes(document), [
        ParagraphBlock,
        CodeBlock,
        ParagraphBlock,
        ParagraphBlock,
      ]);
      expect(listAt(document, 0), [0, 2, 3]);
    });

    test('a table in an item ends where the item ends', () {
      final document = MarkdownDocument.parse('- a\n  | x |\n  |---|\n| 1 |');
      expect(leafTypes(document), [
        ParagraphBlock,
        TableBlock,
        TableBlock,
        ParagraphBlock,
      ]);
    });

    test('a line that starts another block ends a table', () {
      final document = MarkdownDocument.parse(
        '| a | b |\n|---|---|\n- x | y\n> q | r',
      );
      expect(leafTypes(document).sublist(2), [ParagraphBlock, ParagraphBlock]);
      expect(isItem(document, 2), isTrue);
      expect(isInQuote(document, 3), isTrue);
    });

    test("an item's text over a delimiter row in it is a table", () {
      final document = MarkdownDocument.parse('- a | b\n  --|--');
      expect(isItem(document, 0), isTrue);
      expect(leafTypes(document), [TableBlock, TableBlock]);
    });

    test('a heading below lazy text is in the item, not text', () {
      final document = MarkdownDocument.parse('10. a\n    - b\n     # h');
      expect(document.outline.lineDepth(document.lines[2].id), 1);
      expect(subtreeAt(document, 1), (start: 1, end: 2));
    });

    test('text right below a quote in an item continues both', () {
      final document = MarkdownDocument.parse('- a\n  > q\nlazy\n- b');
      expect(isInQuote(document, 2), isTrue);
      expect(document.outline.lineDepth(document.lines[2].id), 1);
      expect(listAt(document, 0), [0, 3]);
    });

    test('only a list from 1 starts right below text', () {
      expect(
        isItem(MarkdownDocument.parse('The year\n2024. was good'), 1),
        isFalse,
      );
      expect(isItem(MarkdownDocument.parse('Steps\n1. go'), 1), isTrue);
      expect(isItem(MarkdownDocument.parse('Steps\n- go'), 1), isTrue);
    });

    test('unlike in Markdown, an empty item starts a list below text', () {
      expect(isItem(MarkdownDocument.parse('Shopping\n- '), 1), isTrue);
      expect(isItem(MarkdownDocument.parse('Shopping\n1.'), 1), isTrue);
      final dash = MarkdownDocument.parse('Shopping\n-');
      expect(isItem(dash, 1), isTrue);
      expect(dash.leafOf(dash.lines.first.id), isA<ParagraphBlock>());
    });

    test('below an item\'s text, only a list from 1 starts a subitem', () {
      final other = MarkdownDocument.parse('- a\n  2. b');
      expect(isItem(other, 1), isFalse);
      expect(depths(other), [0, 1]);
      final one = MarkdownDocument.parse('- a\n  1. b');
      expect(isItem(one, 1), isTrue);
      expect(depths(one), [0, 1]);
    });

    test('text over === or --- is a heading', () {
      final document = MarkdownDocument.parse(
        'Big\ntitle\n===\nSmall\n---\n\n---',
      );
      expect(
        [
          for (final line in document.lines)
            switch (document.leafOf(line.id)) {
              HeadingBlock(:final level) => level,
              _ => null,
            },
        ],
        [1, 1, 1, 2, 2, null, null],
      );
    });

    test('an underline under an item is no heading', () {
      final document = MarkdownDocument.parse('- a\n---');
      expect(leafTypes(document), [ParagraphBlock, RuleBlock]);
      expect(subtreeAt(document, 0), (start: 0, end: 1));
    });
  });

  group('items in quotes', () {
    test('are items, at the depth of the items they are in', () {
      final document = MarkdownDocument.parse('> - a\n>   - b\n>\n> text');
      expect(depths(document), [0, 1, 0, 0]);
      expect(listAt(document, 0), [0]);
      expect(subtreeAt(document, 0), (start: 0, end: 2));
    });

    test('marginOuterOf gives the quote marks outside any item', () {
      final document = MarkdownDocument.parse('> > a\n- > b\n> - > c\ntext');
      expect(
        [
          for (final line in document.lines)
            document.outline.marginOuterOf(line),
        ],
        ['> > ', '', '> ', ''],
      );
      expect(document.outline.marginOuterOf(null), '');
    });
  });
}
