import 'package:test/test.dart';
import 'package:truce_core/src/markdown/outline.dart';
import 'package:truce_core/truce_core.dart';

/// The structure read once from a document's lines.
void main() {
  Outline outlineOf(String text) => MarkdownLines.parse(text).outline;

  test('an item holds the deeper lines below, blank lines among them', () {
    final outline = outlineOf(
      '- a\n  - b\n    text\n- c\n  - d\n\n  more\n\n- e',
    );
    expect(outline.subtree(0), (start: 0, end: 3));
    expect(outline.subtree(1), (start: 1, end: 3));
    expect(outline.subtree(3), (start: 3, end: 7));
    expect(outline.subtree(5), (start: 5, end: 6));
    expect(outline.subtree(8), (start: 8, end: 9));
  });

  test("a line right below an item's text continues the item", () {
    final outline = outlineOf('- a\ntext\n- b\n# H\n- c');
    expect(outline.subtree(0), (start: 0, end: 2));
    expect(outline.listOf(2), [0, 2]);
    expect(outline.listOf(4), [4]);
  });

  test('only items hold lines; others are leaves', () {
    final outline = outlineOf('text\n  more\n- a');
    expect(outline.subtree(0), (start: 0, end: 1));
    expect([for (var i = 0; i < 3; i++) outline.depthAt(i)], [0, 0, 0]);
  });

  test('a code block stays under its item, whatever its lines hold', () {
    final outline = outlineOf('- a\n  ```\n  - code\n\n  ```\n- b');
    expect(outline.subtree(0), (start: 0, end: 5));
    expect(outline.depthAt(2), 1);
    expect(outline.isItem(2), isFalse);
  });

  test('a code line not indented to the item ends the item and the code', () {
    final outline = outlineOf('- a\n  ```\ncode\n- b');
    expect(outline.subtree(0), (start: 0, end: 2));
    expect(outline.kinds, [
      LineKind.plain,
      LineKind.fence,
      LineKind.plain,
      LineKind.plain,
    ]);
    expect(outline.isItem(3), isTrue);
  });

  test('depth is the number of items a line is under', () {
    final outline = outlineOf('- a\n      - b\n  - c\n        text');
    expect([for (var i = 0; i < 4; i++) outline.depthAt(i)], [0, 1, 1, 2]);
  });

  test('a margin item is the top item a line is under', () {
    final outline = outlineOf('- a\n  - b\n    - c\n- d\n\ntext\n  - e');
    expect(
      [
        for (final i in [0, 1, 2, 3, 6]) outline.marginItemOf(i),
      ],
      [0, 0, 0, 3, 6],
    );
  });

  test('only an item has a margin item', () {
    expect(
      () => outlineOf('- a\n  text').marginItemOf(1),
      throwsA(isA<AssertionError>()),
    );
  });

  test('a list is a run of items at one level', () {
    final outline = outlineOf(
      '- a\n\n  text\n- b\n  - x\n\n  y\n  - z\n# H\n- c',
    );
    expect(outline.listOf(0), [0, 3]);
    expect(outline.listOf(3), [0, 3]);
    expect(outline.listOf(4), [4]);
    expect(outline.listOf(7), [7]);
    expect(outline.listOf(9), [9]);
  });

  test('parts: lists without trailing blanks, tables, other lines', () {
    final outline = outlineOf('# H\n- a\n  - b\n\n| x |\n|---|\n| 1 |\ntext');
    expect(
      [
        for (final part in outline.parts)
          (part.runtimeType, part.span.start, part.span.end),
      ],
      [
        (LinePart, 0, 1),
        (ListPart, 1, 3),
        (LinePart, 3, 4),
        (TablePart, 4, 7),
        (LinePart, 7, 8),
      ],
    );
    expect(outline.lists, [(start: 1, end: 3)]);
  });

  test('a line that is no item ends a numbered run', () {
    final outline = outlineOf('1. a\n   1. x\n\n   y\n   1. z');
    expect(outline.numberAt(4), 1);
  });

  test('another delimiter starts the count anew', () {
    final outline = outlineOf('1. a\n2. b\n5) c\n1) d');
    expect([for (var i = 0; i < 4; i++) outline.numberAt(i)], [1, 2, 5, 6]);
  });

  test('numbers and depths are read per line', () {
    final outline = outlineOf('2. a\n   - x\n   4. y\n   1. z\n1. b');
    expect(
      [for (var i = 0; i < 5; i++) outline.numberAt(i)],
      [2, null, 4, 5, 3],
    );
    expect([for (var i = 0; i < 5; i++) outline.depthAt(i)], [0, 1, 1, 1, 0]);
  });

  group('a line put at a level lands', () {
    String placed(String text, int index, int depth) =>
        switch (outlineOf(text).placeAt(index, depth)) {
          AtMargin() => 'margin',
          BesideItem(:final item) => 'beside ${item.text}',
          UnderItem(:final item, :final depth) => 'under ${item.text} $depth',
        };

    test('beside the item below at that level, past blank lines', () {
      expect(placed('- a\n  - b', 1, 1), 'beside b');
      expect(placed('- a\n\n- b', 1, 0), 'beside b');
    });

    test('beside an item at that level above', () {
      expect(placed('- a\n  - b\n- c', 2, 1), 'beside b');
      expect(placed('  - a\n  - b', 2, 0), 'beside b');
    });

    test('at the margin at the top level, with no list above', () {
      expect(placed('text', 1, 0), 'margin');
      expect(placed('', 0, 0), 'margin');
    });

    test('under the deepest item above, as deep as it lets', () {
      expect(placed('- a', 1, 1), 'under a 1');
      expect(placed('- a', 1, 3), 'under a 1');
      expect(placed('- a\n  - b', 2, 3), 'under b 2');
    });

    test('at the margin for a deeper level with no item above', () {
      expect(placed('text', 1, 1), 'margin');
    });
  });

  group('lines meet the open items first, then are read inside them', () {
    List<int> depths(Outline outline, int count) => [
      for (var i = 0; i < count; i++) outline.depthAt(i),
    ];

    test("a line is in an item only if indented to the item's text", () {
      expect(depths(outlineOf('1. a\n  - b'), 2), [0, 0]);
      expect(depths(outlineOf('- a\n - b'), 2), [0, 0]);
      expect(depths(outlineOf('1. a\n   - b'), 2), [0, 1]);
      expect(outlineOf('-   a\n\n  b').subtree(0), (start: 0, end: 1));
      expect(outlineOf('-   a\n\n    b').subtree(0), (start: 0, end: 3));
    });

    test('a tab counts to the next tab stop', () {
      expect(depths(outlineOf('- a\n \t- b'), 2), [0, 1]);
      expect(depths(outlineOf('1. a\n  \t- b'), 2), [0, 1]);
    });

    test('a code fence is read from the content of a nested item', () {
      final outline = outlineOf('- a\n  - b\n    ```\n    - x\n    ```\n- c');
      expect(outline.kinds.sublist(2, 5), [
        LineKind.fence,
        LineKind.code,
        LineKind.fence,
      ]);
      expect(outline.isItem(3), isFalse);
      expect(outline.depthAt(3), 2);
      expect(outline.isItem(5), isTrue);
    });

    test('an unclosed fence in an item ends where the item ends', () {
      final outline = outlineOf('- [ ] a\n  ```\n- [ ] b\n- [ ] c');
      expect(outline.kinds, [
        LineKind.plain,
        LineKind.fence,
        LineKind.plain,
        LineKind.plain,
      ]);
      expect(outline.listOf(0), [0, 2, 3]);
    });

    test('a table in an item ends where the item ends', () {
      final outline = outlineOf('- a\n  | x |\n  |---|\n| 1 |');
      expect(outline.kinds, [
        LineKind.plain,
        LineKind.table,
        LineKind.table,
        LineKind.plain,
      ]);
    });

    test('text right below a quote in an item continues both', () {
      final outline = outlineOf('- a\n  > q\nlazy\n- b');
      expect(outline.isQuote(2), isTrue);
      expect(outline.depthAt(2), 1);
      expect(outline.listOf(0), [0, 3]);
    });

    test('only a list from 1 starts right below text', () {
      expect(outlineOf('The year\n2024. was good').isItem(1), isFalse);
      expect(outlineOf('Steps\n1. go').isItem(1), isTrue);
      expect(outlineOf('Steps\n- go').isItem(1), isTrue);
    });

    test('unlike in Markdown, an empty item starts a list below text', () {
      expect(outlineOf('Shopping\n- ').isItem(1), isTrue);
      expect(outlineOf('Shopping\n-').underlinedHeadingAt(0), isNull);
    });

    test("unlike in Markdown, any item below an item's text is a subitem", () {
      final outline = outlineOf('- a\n  2. b');
      expect(outline.isItem(1), isTrue);
      expect(outline.depthAt(1), 1);
    });

    test('text over === or --- is a heading', () {
      final outline = outlineOf('Big\ntitle\n===\nSmall\n---\n\n---');
      expect(
        [for (var i = 0; i < 7; i++) outline.underlinedHeadingAt(i)],
        [1, 1, 1, 2, 2, null, null],
      );
    });

    test('an underline under an item is no heading', () {
      final outline = outlineOf('- a\n---');
      expect(outline.underlinedHeadingAt(0), isNull);
      expect(outline.subtree(0), (start: 0, end: 1));
    });
  });
}
