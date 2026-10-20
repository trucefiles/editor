import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// What the block tree holds beyond the HTML the spec examples check:
/// which line is where, what of each line its containers take, where
/// blank lines go, and what this reader reads differently on purpose.
void main() {
  /// The tree of [source] in short: containers with their blocks in
  /// brackets, leaves with their text in parentheses.
  String shape(String source) => _shape(MarkdownDocument.parse(source).root);

  /// The leaf line [raw] of [source] is in, with that line.
  (LeafBlock, LeafLine) lineOf(String source, String raw) {
    final document = MarkdownDocument.parse(source);
    final line = document.lines.firstWhere((line) => line.raw == raw);
    final leaf = document.leafOf(line.id);
    return (leaf, leaf.lineOf(line.id));
  }

  /// Each container that takes part of the line [raw] of [source], with
  /// the part it takes in quotes; then where the leaf's content starts.
  List<String> partsOf(String source, String raw) {
    final (_, line) = lineOf(source, raw);
    return [
      for (final (:container, :start, :end) in line.prefix)
        '${_name(container)} "${raw.substring(start, end)}"',
      'content at ${line.contentStart}',
    ];
  }

  group('lines', () {
    test('every line is in exactly one leaf, leaves in file order', () {
      const source =
          '# h\n- a\n\n  b\n    - c\n\n      d\n> e\n>\n> f\n\n```\nx\n```';
      final document = MarkdownDocument.parse(source);

      expect([
        for (final leaf in document.leaves)
          for (final line in leaf.lines) line.id,
      ], document.lines.map((line) => line.id));
    });

    test("a leaf's text is its lines' contents, joined", () {
      final (leaf, _) = lineOf('> - a\n>   b', '> - a');

      expect(leaf.text, 'a\nb');
      expect(leaf.lineStarts, [0, 2]);
      expect([leaf.lineAt(0), leaf.lineAt(1), leaf.lineAt(2)], [0, 0, 1]);
    });
  });

  group("a line's prefix", () {
    test('each container takes its marks, outermost first', () {
      expect(partsOf('> - [x] a', '> - [x] a'), [
        'quote "> "',
        'item "- [x] "',
        'content at 8',
      ]);
      expect(partsOf('1. a\n   > q', '   > q'), [
        'item "   "',
        'quote "> "',
        'content at 5',
      ]);
      expect(partsOf('> > a', '> > a'), [
        'quote "> "',
        'quote "> "',
        'content at 4',
      ]);
    });

    test("an item takes its content's indent on its later lines", () {
      expect(partsOf('- a\n  b', '  b'), ['item "  "', 'content at 2']);
      expect(partsOf('10. a\n\n    b', '    b'), [
        'item "    "',
        'content at 4',
      ]);
    });

    test('content starts at its first character that is not a space', () {
      expect(partsOf('-   a', '-   a'), ['item "-   "', 'content at 4']);
      expect(partsOf('>  a', '>  a'), ['quote "> "', 'content at 3']);
    });

    test('a code block keeps the spaces past its indent', () {
      final (leaf, line) = lineOf('-      code', '-      code');

      expect(leaf, isA<CodeBlock>());
      expect(line.contentStart, 6);
      expect(leaf.text, ' code');
    });

    test('a tab taken in part shows as spaces in a code block', () {
      final (leaf, line) = lineOf('>\t\tcode', '>\t\tcode');

      expect(leaf, isA<CodeBlock>());
      expect(line.virtualSpaces, 2);
    });

    test('a lazy line lacks the marks of the containers it goes on in', () {
      expect(partsOf('> a\nlazy', 'lazy'), ['content at 0']);
      expect(partsOf('> - a\n> lazy', '> lazy'), [
        'quote "> "',
        'content at 2',
      ]);
      expect(shape('> - a\n> lazy'), 'quote[list[item[p(a\nlazy)]]]');
    });
  });

  group('blank lines', () {
    test('go to the deepest container their indent and marks reach', () {
      expect(shape('- a\n\n- b'), 'list[item[p(a)], blank, item[p(b)]]');
      expect(shape('- a\n  \n- b'), 'list[item[p(a), blank], item[p(b)]]');
      expect(shape('> a\n>\n> b'), 'quote[p(a), blank, p(b)]');
      expect(shape('> a\n\nb'), 'quote[p(a)], blank, p(b)');
      expect(
        shape('1. a\n   > q\n   >\n   > r'),
        'list[item[p(a), quote[p(q), blank, p(r)]]]',
      );
    });

    test('but stay in a container that goes on below them', () {
      expect(shape('- a\n\n  b'), 'list[item[p(a), blank, p(b)]]');
      expect(shape('> - a\n>\n>   b'), 'quote[list[item[p(a), blank, p(b)]]]');
      expect(
        shape('- a\n  - b\n\n  c'),
        'list[item[p(a), list[item[p(b)]], blank, p(c)]]',
      );
      expect(
        shape('- a\n\n\n    \n    b'),
        'list[item[p(a), blank, blank, blank, p(b)]]',
      );
    });

    test('keep only the prefix of the container they reach', () {
      expect(partsOf('> - a\n>\n>   b', '>'), ['quote ">"', 'content at 1']);
      expect(partsOf('- a\n\n  b', ''), ['content at 0']);
    });

    test("an empty item's marker line is its blank line", () {
      expect(shape('-\n- a'), 'list[item[blank], item[p(a)]]');
      expect(partsOf('-\n- a', '-'), ['item "-"', 'content at 1']);
      expect(shape('- [ ] '), 'list[item[blank]]');
    });

    test('after an indented code block, they are its container\'s', () {
      expect(shape('    a\n\n    b\n\nc'), 'code(a\n\nb), blank, p(c)');
    });
  });

  group('code blocks', () {
    test('fenced code holds its fences', () {
      const source = 'a\n\n```dart\n# no heading\n```\nb';
      final (code as CodeBlock, _) = lineOf(source, '```dart');

      expect(
        shape(source),
        'p(a), blank, code(```dart\n# no heading\n```), p(b)',
      );
      expect((code.fenced, code.closed, code.info), (true, true, 'dart'));
      expect(code.codeLines.map((line) => line.content), ['# no heading']);
    });

    test('an unclosed fence runs to the end of its container', () {
      expect(shape('~~~\na\n```'), 'code(~~~\na\n```)');
      expect(shape('> ```\n> a\n\nb'), 'quote[code(```\na)], blank, p(b)');
      final (code, _) = lineOf('~~~\na', '~~~');
      expect((code as CodeBlock).closed, isFalse);
    });
  });

  group('tables', () {
    test('need a delimiter row with as many cells', () {
      expect(
        shape('| a | b |\n|---|:-:|\n| 1 | 2 |\n\nx | y'),
        'table(| a | b |\n|---|:-:|\n| 1 | 2 |), blank, p(x | y)',
      );
      expect(shape('a | b\n---'), 'h2(a | b\n---)');
      expect(shape('| a | b |\n|---|'), 'p(| a | b |\n|---|)');
      expect(shape('x\na|b\n-|-\ny'), 'p(x), table(a|b\n-|-\ny)');
    });

    test('read their cells without the delimiter row', () {
      final (table, _) = lineOf('| a | b \\| c |\n|---|--:|\n|1|', '|1|');
      final rows = (table as TableBlock).cells;

      expect(table.alignments, [CellAlignment.none, CellAlignment.right]);
      expect(
        [
          for (final (index, row) in rows.indexed)
            [
              for (final cell in row)
                cell == null
                    ? null
                    : table.lines[index == 0 ? 0 : index + 1].content.substring(
                        cell.start,
                        cell.end,
                      ),
            ],
        ],
        [
          ['a', 'b \\| c'],
          ['1', null],
        ],
      );
    });
  });

  group('front matter', () {
    test('`---` lines at the very top enclose it', () {
      expect(
        shape('---\ntitle: x\n---\n# h'),
        'front(---\ntitle: x\n---), h1(# h)',
      );
      expect(shape('---\na: b\n...\nc'), 'front(---\na: b\n...), p(c)');
    });

    test('anywhere else, or unclosed, they are no front matter', () {
      expect(shape('\n---\na\n---'), 'blank, rule(---), h2(a\n---)');
      expect(shape('---\na'), 'rule(---), p(a)');
    });
  });

  group('deliberate deviations, for typing', () {
    test('an empty list item interrupts a paragraph', () {
      expect(shape('text\n-\nmore'), 'p(text), list[item[blank]], p(more)');
      expect(shape('text\n1.'), 'p(text), list[item[blank]]');
    });

    test('a single `-` below text is such an item, not an underline', () {
      expect(shape('Title\n-'), 'p(Title), list[item[blank]]');
      expect(shape('Title\n--'), 'h2(Title\n--)');
    });
  });
}

String _name(MarkdownBlock block) => switch (block) {
  RootBlock() => 'root',
  QuoteBlock() => 'quote',
  ListBlock() => 'list',
  ItemBlock() => 'item',
  ParagraphBlock() => 'p',
  HeadingBlock(:final level) => 'h$level',
  CodeBlock() => 'code',
  HtmlBlock() => 'html',
  TableBlock() => 'table',
  RuleBlock() => 'rule',
  DefinitionsBlock() => 'definitions',
  FrontMatterBlock() => 'front',
  BlankBlock() => 'blank',
};

String _shape(MarkdownBlock block) => switch (block) {
  RootBlock(:final children) => children.map(_shape).join(', '),
  ContainerBlock(:final children) =>
    '${_name(block)}[${children.map(_shape).join(', ')}]',
  BlankBlock() => 'blank',
  LeafBlock(:final text) => '${_name(block)}($text)',
};
