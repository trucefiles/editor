import 'package:test/test.dart';
import 'package:truce_core/src/markdown/outline.dart';
import 'package:truce_core/truce_core.dart';

/// The structure read once from a document's lines.
void main() {
  Outline outlineOf(String text) => MarkdownLines.parse(text).outline;

  test('a subtree holds the deeper lines below, up to an empty line', () {
    final outline = outlineOf('- a\n  - b\n    text\n- c\n  - d\n\n  more');
    expect(outline.subtree(0), (start: 0, end: 3));
    expect(outline.subtree(1), (start: 1, end: 3));
    expect(outline.subtree(3), (start: 3, end: 5));
    expect(outline.subtree(5), (start: 5, end: 7));
  });

  test('a margin item is the top of its run of items', () {
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

  test('a list region ends at a line at the margin', () {
    final outline = outlineOf('- a\n\n  text\n- b\n# H\n- c');
    expect(outline.regionOf(0), (start: 0, end: 4));
    expect(outline.regionOf(3), (start: 0, end: 4));
    expect(outline.regionOf(4), (start: 4, end: 5));
    expect(outline.regionOf(5), (start: 5, end: 6));
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

  test('numbers and depths are read per line', () {
    final outline = outlineOf('2. a\n   - x\n   4. y\n   1. z\n1. b');
    expect(
      [for (var i = 0; i < 5; i++) outline.numberAt(i)],
      [2, null, 4, 5, 3],
    );
    expect([for (var i = 0; i < 5; i++) outline.depthAt(i)], [0, 1, 1, 1, 0]);
  });
}
