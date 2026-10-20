import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// What the format buttons do to a line's text.
void main() {
  group('toggleWrap', () {
    test('wraps the selection', () {
      expect(toggleWrap('a bc d', 2, 4, '**'), (
        text: 'a **bc** d',
        start: 4,
        end: 6,
      ));
    });

    test('unwraps a selection inside the marks', () {
      expect(toggleWrap('a **bc** d', 4, 6, '**'), (
        text: 'a bc d',
        start: 2,
        end: 4,
      ));
    });

    test('unwraps a selection that includes the marks', () {
      expect(toggleWrap('a **bc** d', 2, 8, '**'), (
        text: 'a bc d',
        start: 2,
        end: 4,
      ));
    });

    test('italic on bold text makes it bold italic, and back', () {
      expect(toggleWrap('**a**', 2, 3, '*'), (
        text: '***a***',
        start: 3,
        end: 4,
      ));
      expect(toggleWrap('***a***', 3, 4, '*'), (
        text: '**a**',
        start: 2,
        end: 3,
      ));
      expect(toggleWrap('**a**', 0, 5, '*'), (
        text: '***a***',
        start: 1,
        end: 6,
      ));
    });

    test('bold on bold italic text leaves it italic', () {
      expect(toggleWrap('***a***', 3, 4, '**'), (
        text: '*a*',
        start: 1,
        end: 2,
      ));
    });

    test('an empty selection gets a pair to type into', () {
      expect(toggleWrap('ab', 1, 1, '*'), (text: 'a**b', start: 2, end: 2));
    });
  });

  test('insertLink links the selection, or shows the url', () {
    expect(insertLink('see here', 4, 8, 'https://x.org'), (
      text: 'see [here](https://x.org)',
      start: 25,
      end: 25,
    ));
    expect(
      insertLink('', 0, 0, 'https://x.org').text,
      '[https://x.org](https://x.org)',
    );
  });

  test('cycleHeading goes through three levels and back', () {
    expect(cycleHeading('Title', 2, 2), (text: '# Title', start: 4, end: 4));
    expect(cycleHeading('# Title', 4, 4), (text: '## Title', start: 5, end: 5));
    expect(cycleHeading('### Title', 6, 6), (text: 'Title', start: 2, end: 2));
  });

  test('cycleHeading leaves a quote alone', () {
    expect(cycleHeading('> quote', 3, 3), isNull);
  });

  test('cycleHeading replaces a heading mark after leading spaces', () {
    expect(cycleHeading(' # x', 3, 3), (text: '## x', start: 3, end: 3));
  });
}
