import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// How lines show by their neighbors: numbers of numbered items, quotes.
void main() {
  group('numberOf', () {
    List<int?> numbers(String text) {
      final doc = MarkdownLines.parse(text);
      return [for (final line in doc.lines) doc.numberOf(line)];
    }

    test('counts on from the first number, whatever the others say', () {
      expect(numbers('3. a\n1. b\n1. c'), [3, 4, 5]);
      expect(numbers('1. a\n1. b'), [1, 2]);
    });

    test('each level counts on its own, past subitems and gaps', () {
      expect(numbers('2. a\n   5. x\n   1. y\n\n1. b'), [2, 5, 6, null, 3]);
    });

    test('another kind at the level starts a new count', () {
      expect(numbers('4. a\n- b\n7. c\n1. d'), [4, null, 7, 8]);
    });

    test('a line at the margin ends the list', () {
      expect(numbers('3. a\ntext\n6. b'), [3, null, 6]);
    });

    test('is null for other lines and in code blocks', () {
      expect(numbers('- a\ntext\n```\n1. x\n```'), [
        null,
        null,
        null,
        null,
        null,
      ]);
    });
  });

  group('isQuote', () {
    List<bool> quotes(String text) {
      final doc = MarkdownLines.parse(text);
      return [for (final line in doc.lines) doc.isQuote(line)];
    }

    test('lines with quote marks', () {
      expect(quotes('> a\n>b\ntext'), [true, true, true]);
      expect(quotes('text\n> a'), [false, true]);
    });

    test('an unmarked line continues the quote, as Markdown reads it', () {
      expect(quotes('> a\nb\nc\n\nd'), [true, true, true, false, false]);
    });

    test('a blank quote line or a new block ends it', () {
      expect(quotes('> a\n>\nb'), [true, true, false]);
      expect(quotes('> a\n# h'), [true, false]);
      expect(quotes('> a\n- b'), [true, false]);
      expect(quotes('> a\n---'), [true, false]);
      expect(quotes('> # h\nb'), [true, false]);
    });

    test('code blocks are no quotes', () {
      expect(quotes('> a\n```\n> x\n```'), [true, false, false, false]);
    });
  });
}
