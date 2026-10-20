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

  test('only items hold lines; others are leaves', () {
    final outline = outlineOf('text\n  more\n- a');
    expect(outline.subtree(0), (start: 0, end: 1));
    expect([for (var i = 0; i < 3; i++) outline.depthAt(i)], [0, 0, 0]);
  });

  test('a code block stays under its item, whatever its indent', () {
    final outline = outlineOf('- a\n  ```\ncode\n  ```\n- b');
    expect(outline.subtree(0), (start: 0, end: 4));
    expect(outline.depthAt(2), 1);
  });

  test('depth is the number of items a line is under', () {
    final outline = outlineOf('- a\n      - b\n  - c\n        text');
    expect([for (var i = 0; i < 4; i++) outline.depthAt(i)], [0, 1, 1, 2]);
  });

  test('a margin item is the top item a line is under', () {
    final outline = outlineOf('- a\n  - b\n    - c\n- d\ntext\n  - e');
    expect(
      [
        for (final i in [0, 1, 2, 3, 5]) outline.marginItemOf(i),
      ],
      [0, 0, 0, 3, 5],
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
      '- a\n\n  text\n- b\n  - x\n  y\n  - z\n# H\n- c',
    );
    expect(outline.listOf(0), [0, 3]);
    expect(outline.listOf(3), [0, 3]);
    expect(outline.listOf(4), [4]);
    expect(outline.listOf(6), [6]);
    expect(outline.listOf(8), [8]);
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
}
