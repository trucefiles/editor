import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/highlight/highlights.dart';

import '../support/document_corpus.dart';

/// The highlights of each line of [text], as `kind:shown` strings.
List<List<String>> _shown(String text) {
  final tree = DocumentTree.read(text);
  return [
    for (final line in tree.lines)
      [
        for (final span in highlightsOf(tree, line.id))
          '${_name(span.highlight)}:'
              '${line.text.substring(span.start, span.end)}',
      ],
  ];
}

String _name(Highlight highlight) => switch (highlight) {
  TextHighlight(:final name) => name,
  HeadingHighlight(:final level) => 'h$level',
  LinkHighlight(:final destination) => 'link $destination',
};

void main() {
  test('a heading: its text and its marks', () {
    expect(_shown('## Title ##'), [
      ['h2:## Title ##', 'mark:## ', 'mark: ##'],
    ]);
  });

  test('formatted text: what it is, its marks', () {
    expect(_shown('a **b** `c` [d](e)'), [
      [
        'strong:b',
        'mark:**',
        'mark:**',
        'code:`c`',
        'mark:`',
        'mark:`',
        'link e:d',
        'mark:[',
        'mark:](e)',
      ],
    ]);
  });

  test('a list item and a quote: their marks', () {
    expect(_shown('- [ ] a\n> b'), [
      ['mark:- [ ] '],
      ['mark:> '],
    ]);
  });

  test('a span over two lines shows on each', () {
    expect(_shown('*a\nb*'), [
      ['emphasis:a', 'mark:*'],
      ['emphasis:b', 'mark:*'],
    ]);
  });

  test('a fenced code block: fences as marks, code as code', () {
    expect(_shown('```\nx\n```'), [
      ['mark:```'],
      ['code:x'],
      ['mark:```'],
    ]);
  });

  test('raw blocks and layout lines', () {
    expect(_shown('<div>\n\n-\n\n[a]: b'), [
      ['raw:<div>'],
      <String>[],
      ['mark:-'],
      <String>[],
      ['raw:[a]: b'],
    ]);
  });

  test('every span lies within its line', () {
    for (final text in documentCorpus) {
      final tree = DocumentTree.read(text);
      for (final line in tree.lines) {
        for (final span in highlightsOf(tree, line.id)) {
          expect(span.start, inInclusiveRange(0, span.end), reason: text);
          expect(span.end, lessThanOrEqualTo(line.text.length), reason: text);
        }
      }
    }
  });
}
