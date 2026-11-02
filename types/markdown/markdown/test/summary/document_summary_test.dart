import 'package:test/test.dart';
import 'package:truce_markdown/truce_markdown.dart';

void main() {
  String preview(String text, {int maxLines = 6, bool hideDone = false}) {
    final summary = DocumentSummary.of(text, maxLines: maxLines);
    return summary.preview(MarkdownPreview(hideChecked: hideDone));
  }

  String? title(String text) => DocumentSummary.of(text, maxLines: 1).title;

  String firstLine(String text) =>
      DocumentSummary.of(text, maxLines: 1).firstLine;

  group('title', () {
    test('is the first level-1 heading', () {
      expect(title('intro\n## Sub\n# Shopping \n# Later'), 'Shopping');
    });

    test('reads headings as Markdown does: not in code, up to 3 spaces', () {
      expect(title('```\n# Code\n```\n   # Plan'), 'Plan');
      expect(title('    # Code'), isNull);
    });

    test('is none without a level-1 heading', () {
      expect(title('## Sub\ntext'), isNull);
    });
  });

  group('preview', () {
    test('skips the title and empty lines', () {
      expect(
        preview('# T\n\nfirst\n\nsecond\nthird', maxLines: 2),
        'first\nsecond',
      );
    });

    test('keeps file order and shows items as boxes', () {
      expect(
        preview('# T\nintro\n- [ ] a\n- [x] b\n  - [ ] c\n\nend'),
        'intro\n☐ a\n☑ b\n  ☐ c\nend',
      );
    });

    test('drops heading, quote and bullet marks; numbers items', () {
      expect(
        preview('# T\n## Sub\n> quoted\n- one\n  * two\n\n3. x\n4. y'),
        'Sub\nquoted\n• one\n  • two\n3. x\n4. y',
      );
    });

    test('can leave out checked items and count them', () {
      const text = '# T\n- [x] a\n  - [ ] sub\n- [ ] b\n- [x] c\n\nend';
      expect(preview(text, hideDone: true), '☐ b\nend\n+ 2 done');
      expect(preview(text, maxLines: 2, hideDone: true), '☐ b\n+ 2 done');
      expect(preview('# T\n- [ ] a', hideDone: true), '☐ a');
    });

    test('draws dividers, also in items', () {
      expect(preview('# T\na\n\n---\n\nb'), 'a\n─────\nb');
      expect(
        preview('# T\n- [ ] a\n- [ ] -----\n- [x] ***\n- b'),
        '☐ a\n☐ ─────\n☑ ─────\n• b',
      );
    });

    test('leaves out front matter and HTML', () {
      expect(preview('---\nt: x\n---\n<div>\nhi\n</div>\n\ntext'), 'text');
    });
  });

  group('first line', () {
    test('is the first line with words, as plain words', () {
      expect(firstLine('\n  Milk and eggs \nmore'), 'Milk and eggs');
      expect(firstLine('# Plan\n'), 'Plan');
      expect(firstLine('- [ ] call Bob'), 'call Bob');
      expect(firstLine('> - quoted'), 'quoted');
      expect(firstLine('* one'), 'one');
      expect(firstLine(' \n'), '');
    });

    test('skips blocks without words', () {
      expect(firstLine('---\ntitle: x\n---\nHello'), 'Hello');
      expect(firstLine('```\ncode\n```'), 'code');
      expect(firstLine('***\n\nHello'), 'Hello');
    });
  });
}
