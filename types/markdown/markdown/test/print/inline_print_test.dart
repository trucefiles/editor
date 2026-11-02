import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/print/escaping.dart';
import 'package:truce_markdown/src/print/inline_layout.dart';
import 'package:truce_markdown/src/print/inline_printer.dart';
import 'package:truce_markdown/src/print/spans.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/tree/inlines.dart';
import 'package:truce_markdown/src/visible/formatting.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

import '../support/doc_dump.dart';

const _style = (emphasis: '*', strong: '**', strike: '~~');

final _definitions = {'REF': (label: 'ref', destination: '/r', title: null)};

InlineLayout _layout(VisibleText text, {SpanStyle style = _style}) =>
    layoutOf(text, heading: false, definitions: _definitions, style: style);

/// [layout] printed as a paragraph's lines.
String _printed(InlineLayout layout) {
  final lines = [StringBuffer()];
  for (final token in printInline(layout, hardBreak: r'\')) {
    switch (token) {
      case WordToken(:final source):
        lines.last.write(source);
      case SpaceToken():
        lines.last.write(' ');
      case SoftBreakToken():
        lines.add(StringBuffer());
      case HardBreakToken(:final spelling):
        lines.last.write(spelling);
        lines.add(StringBuffer());
    }
  }
  return lines.map((line) => lineStartEscaped(line.toString())).join('\n');
}

VisibleText _readBack(String source) =>
    switch (DocumentTree.read('$source\n\n[ref]: /r').leaves.toList()) {
      [_] => VisibleText.empty,
      [final TextLeaf leaf, _] => visibleTextOf(leaf.text),
      final leaves => throw StateError('not one paragraph: $leaves'),
    };

void main() {
  test('a printed text reads back as its writable form', () {
    for (var round = 0; round < 3000; round++) {
      final random = Random(round + 1000 * _seed);
      final text = _randomText(random);
      final layout = _layout(text);
      final source = _printed(layout);
      final reason = 'text: ${dumpText(text)}\nsource: $source';
      expect(
        dumpText(_layout(layout.text).text),
        dumpText(layout.text),
        reason: 'not settled; $reason',
      );
      expect(
        dumpText(_readBack(source)),
        dumpText(layout.text),
        reason: reason,
      );
    }
  });

  group('prints', () {
    test('spans with their delimiters, whitespace outside', () {
      final text = VisibleText([
        TextPiece('a '),
        TextPiece('b ', Formatting({TextFormat.strong})),
        TextPiece('c'),
      ]);
      expect(_printed(_layout(text)), 'a **b** c');
    });

    test('`_` where the style prefers it and it reads alone', () {
      final text = VisibleText([
        TextPiece('a '),
        TextPiece('b', Formatting({TextFormat.emphasis})),
        TextPiece(' c'),
      ]);
      expect(
        _printed(
          _layout(text, style: (emphasis: '_', strong: '**', strike: '~~')),
        ),
        'a _b_ c',
      );
    });

    test('marks in text escaped', () {
      final text = VisibleText([
        TextPiece('5*3 a_b _c <d> [e] &amp; www.x.io'),
      ]);
      expect(
        _printed(_layout(text)),
        r'5\*3 a_b \_c \<d> \[e] \&amp; www\.x\.io',
      );
    });

    test('a bare link inline where a line start would escape it', () {
      final email = LinkMark(
        destination: 'mailto:-a@x.io',
        style: LinkStyle.extendedAutolink,
      );
      expect(
        _printed(
          _layout(VisibleText([TextPiece('-a@x.io', Formatting({}, email))])),
        ),
        '[-a@x.io](mailto:-a@x.io)',
      );
    });

    test('a bare link inline where text before would read with it', () {
      final www = LinkMark(
        destination: 'http://www.x.io',
        style: LinkStyle.extendedAutolink,
      );
      expect(
        _printed(
          _layout(
            VisibleText([
              TextPiece('me@x.io_'),
              TextPiece('www.x.io', Formatting({}, www)),
            ]),
          ),
        ),
        r'me@x\.io\_[www.x.io](http://www.x.io)',
      );
      expect(
        _printed(
          _layout(
            VisibleText([
              TextPiece(' '),
              TextPiece('www.x.io', Formatting({}, www)),
            ]),
          ),
        ),
        '&#32;[www.x.io](http://www.x.io)',
      );
    });

    test('code padded where a code span would strip its spaces', () {
      expect(codeSpanSource(' \u00a0 '), '`  \u00a0  `');
      expect(codeSpanSource('   '), '`   `');
      expect(codeSpanSource('`a'), '`` `a ``');
    });

    test('a hard break alone on its line as `\\`', () {
      final text = VisibleText([
        TextPiece('a'),
        HardBreakPiece(),
        HardBreakPiece(),
        TextPiece('b'),
      ]);
      expect(
        printInline(
          _layout(text),
          hardBreak: '  ',
        ).whereType<HardBreakToken>().map((token) => token.spelling),
        ['  ', r'\'],
      );
    });
  });
}

/// Another seed for a longer run: `FUZZ_SEED=7 dart test ...`.
final _seed = int.parse(Platform.environment['FUZZ_SEED'] ?? '0');

final _reference = LinkInline(
  '[',
  const [TextInline('ref')],
  ']',
  destination: '/r',
  style: LinkStyle.reference,
);

final _image = ImageInline(
  '![',
  const [TextInline('i')],
  '](p)',
  destination: 'p',
);

const _chunks = [
  'a',
  'b',
  'word',
  ' ',
  '  ',
  'x y',
  '_',
  '*',
  '**',
  '~',
  '`',
  '<',
  '>',
  '[',
  ']',
  '!',
  '&',
  '&amp;',
  '#',
  '.',
  ':',
  '/',
  r'\',
  '-',
  '+',
  '=',
  '|',
  '1)',
  '2.',
  '(',
  ')',
  'www.x.io',
  'https://a.b/c',
  'me@x.io',
  '\u00A0',
  '\u200B',
  'é',
  '😀',
  '"',
  "'",
  'snake_case',
  'a*b',
];

VisibleText _randomText(Random random) {
  final links = [
    LinkMark(destination: 'u', style: LinkStyle.inline),
    LinkMark(destination: 'a b', title: 't"', style: LinkStyle.inline),
    LinkMark(destination: 'https://a.b/c', style: LinkStyle.autolink),
  ];
  LinkMark? link;
  return VisibleText([
    for (var index = random.nextInt(8) + 1; index > 0; index--)
      ...() {
        if (random.nextInt(4) == 0) {
          link = random.nextInt(3) == 0
              ? null
              : links[random.nextInt(links.length)];
        }
        final formats = {
          for (final format in TextFormat.values)
            if (random.nextInt(format == TextFormat.code ? 8 : 3) == 0) format,
        };
        final formatting = Formatting(formats, link);
        final plain = Formatting(formats);
        return switch (random.nextInt(16)) {
          0 => [SoftBreakPiece(formatting)],
          1 => [HardBreakPiece(formatting)],
          2 => [
            TextPiece(
              'www.x.io',
              plain.withLink(
                LinkMark(
                  destination: 'http://www.x.io',
                  style: LinkStyle.extendedAutolink,
                ),
              ),
            ),
          ],
          3 => [
            TextPiece(
              random.nextBool() ? 'ref' : 'other',
              plain.withLink(LinkMark.of(_reference)),
            ),
          ],
          4 => [ObjectPiece(const HtmlInline('<span>'), formatting)],
          5 => [ObjectPiece(_image, formatting)],
          _ => [TextPiece(_chunks[random.nextInt(_chunks.length)], formatting)],
        };
      }(),
  ]);
}
