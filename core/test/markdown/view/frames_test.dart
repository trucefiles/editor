import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// How leaves show by the containers around them: numbers of numbered
/// items, quotes.
void main() {
  /// The view of each leaf of [source], in file order.
  List<LeafView> views(String source) {
    final document = MarkdownDocument.parse(source);
    return [for (final leaf in document.leaves) LeafView.of(document, leaf)];
  }

  group('the number beside a leaf', () {
    List<int?> numbers(String source) => [
      for (final view in views(source)) view.markedItem?.number,
    ];

    test('counts on from the first number, whatever the others say', () {
      expect(numbers('3. a\n1. b\n1. c'), [3, 4, 5]);
      expect(numbers('1. a\n1. b'), [1, 2]);
    });

    test('each level counts on its own, past subitems and gaps', () {
      expect(numbers('2. a\n\n   5. x\n   1. y\n\n1. b'), [
        2,
        null,
        5,
        6,
        null,
        3,
      ]);
    });

    test('below text, only a 1 starts a list; other numbers are text', () {
      expect(numbers('2. a\n   5. x\n   1. y'), [2, 1]);
    });

    test('another kind of item starts a new count', () {
      expect(numbers('4. a\n- b\n7. c\n1. d'), [4, null, 7, 8]);
      expect(numbers('1. a\n5) b'), [1, 5]);
    });

    test('a block at the margin ends the list', () {
      expect(numbers('3. a\n\ntext\n\n6. b'), [3, null, null, null, 6]);
    });

    test("a line right below an item's text continues it", () {
      expect(numbers('3. a\ntext\n6. b'), [3, 4]);
    });

    test('shows only beside the first leaf of an item', () {
      expect(numbers('3. a\n\n   b\n4. c'), [3, null, null, 4]);
    });

    test('is null beside other leaves and code blocks', () {
      expect(numbers('- a\ntext\n```\n1. x\n```'), [null, null]);
    });
  });

  group('quoted', () {
    List<bool> quotes(String source) => [
      for (final view in views(source)) view.quoted,
    ];

    test('leaves in a quote', () {
      expect(quotes('> a\n>b\ntext'), [true]);
      expect(quotes('text\n\n> a'), [false, false, true]);
    });

    test('an unmarked line continues the quote, as Markdown reads it', () {
      expect(quotes('> a\nb\nc\n\nd'), [true, false, false]);
    });

    test('a blank quote line is in it; a new block ends it', () {
      expect(quotes('> a\n>\nb'), [true, true, false]);
      expect(quotes('> a\n# h'), [true, false]);
      expect(quotes('> a\n- b'), [true, false]);
      expect(quotes('> a\n---'), [true, false]);
      expect(quotes('> # h\nb'), [true, false]);
    });

    test('a code block after a quote is in none', () {
      expect(quotes('> a\n```\n> x\n```'), [true, false]);
    });
  });
}
