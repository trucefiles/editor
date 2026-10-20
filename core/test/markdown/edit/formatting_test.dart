import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// What the format buttons do to a block's text.
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

    test('strike, and marks around text of several lines', () {
      expect(toggleWrap('~~a~~', 2, 3, '~~'), (text: 'a', start: 0, end: 1));
      expect(toggleWrap('a\nb', 0, 3, '**'), (
        text: '**a\nb**',
        start: 2,
        end: 5,
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

  group('cycleHeading', () {
    test('goes through three levels and back', () {
      expect(cycleHeading('Title', 2, 2), (text: '# Title', start: 4, end: 4));
      expect(cycleHeading('# Title', 4, 4), (
        text: '## Title',
        start: 5,
        end: 5,
      ));
      expect(cycleHeading('### Title', 6, 6), (
        text: 'Title',
        start: 2,
        end: 2,
      ));
      expect(cycleHeading('', 0, 0), (text: '# ', start: 2, end: 2));
    });

    test('keeps closing marks', () {
      expect(cycleHeading('## a ##', 3, 4), (
        text: '### a ##',
        start: 4,
        end: 5,
      ));
    });

    test('changes the line the selection starts in', () {
      expect(cycleHeading('a\nb', 2, 3), (text: 'a\n# b', start: 4, end: 5));
    });

    test('over an underline: `===` to `---`, then `###` on its text', () {
      expect(cycleHeading('Title\n===', 2, 2), (
        text: 'Title\n---',
        start: 2,
        end: 2,
      ));
      expect(cycleHeading('Title\n---', 2, 4), (
        text: '### Title',
        start: 6,
        end: 8,
      ));
      expect(cycleHeading('Title\n---', 7, 9), (
        text: '### Title',
        start: 9,
        end: 9,
      ));
    });

    test('a single `-` below text is no underline', () {
      expect(cycleHeading('a\n-', 0, 0), (text: '# a\n-', start: 2, end: 2));
    });
  });
}
