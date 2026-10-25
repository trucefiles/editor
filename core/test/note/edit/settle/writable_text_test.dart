import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/src/note/read/inline_reader.dart';
import 'package:truce_core/src/note/tree/inlines.dart';
import 'package:truce_core/src/note/tree/note_style.dart';
import 'package:truce_core/src/note/visible/formatting.dart';
import 'package:truce_core/src/note/visible/visible_text.dart';
import 'package:truce_core/src/note/edit/settle/writable_text.dart';
import 'package:truce_core/src/note/write/inline/inline_writing.dart';

const _paragraph = ParagraphShape(
  edited: (start: 0, end: 1 << 30),
  width: 120,
  prefix: 0,
);

final _bold = Formatting({TextFormat.strong});

/// The source [text] writes once made writable, and its tail's text.
(String, String) _written(VisibleText text, {TextShape shape = _paragraph}) {
  final writable = writableText(text, shape: shape);
  final source = inlineSource(
    old: const [],
    oldText: VisibleText.empty,
    text: writable.text,
    lines: shape is HeadingShape && !shape.setext
        ? TextLines.atxHeading
        : TextLines.paragraph,
    style: const NoteStyle(),
    definitions: const {},
  )!;
  expect(
    visibleTextOf(readInlineText(source)).looksLike(writable.text),
    isTrue,
    reason: source,
  );
  return (source, writable.tail.text);
}

VisibleText _text(List<VisiblePiece> pieces) => VisibleText(pieces);

void main() {
  test('trailing spaces and breaks stay in the tail', () {
    expect(_written(_text([TextPiece('a  ')])), ('a', '  '));
    expect(_written(_text([TextPiece('a'), HardBreakPiece()])), ('a', '\n'));
    expect(_written(_text([TextPiece('   ')])), ('', '   '));
  });

  test('a line break wrapped in the file beside a space joins the lines', () {
    expect(
      _written(_text([TextPiece('a '), SoftBreakPiece(), TextPiece('b')])).$1,
      'a  b',
    );
    expect(
      _written(_text([TextPiece('a'), SoftBreakPiece(), TextPiece('b')])).$1,
      'a\nb',
    );
  });

  test('whitespace at a span\'s edges moves out of it', () {
    expect(
      _written(_text([TextPiece('a'), TextPiece(' b ', _bold), TextPiece('c')]))
          .$1,
      'a **b** c',
    );
    expect(
      _written(_text([TextPiece('a'), TextPiece(' ', _bold), TextPiece('c')]))
          .$1,
      'a c',
    );
  });

  test('a span delimiters cannot write snaps to edges that can', () {
    expect(
      _written(
        _text([TextPiece('foo'), TextPiece('"bar"', _bold), TextPiece('baz')]),
      ).$1,
      'foo"**bar**"baz',
    );
  });

  test('bare links are links as GitHub reads them', () {
    final text = writableText(
      _text([TextPiece('see www.example.com.')]),
      shape: _paragraph,
    ).text;
    expect(text.pieces.map((piece) => piece.formatting.link?.destination), [
      null,
      'http://www.example.com',
      null,
    ]);
    expect(
      _written(_text([TextPiece('see www.example.com.')])).$1,
      'see www.example.com.',
    );
  });

  test('text that is no longer a bare link loses the link', () {
    final link = LinkMark(
      destination: 'http://www.example.com',
      style: LinkStyle.extendedAutolink,
    );
    final text = writableText(
      _text([TextPiece('ww.example.com', Formatting(const {}, link))]),
      shape: _paragraph,
    ).text;
    expect(text.pieces.single.formatting.link, isNull);
  });

  test('a link found where one was keeps its mark', () {
    final link = LinkMark(
      destination: 'http://www.example.com',
      style: LinkStyle.extendedAutolink,
    );
    final text = writableText(
      _text([TextPiece('www.example.com', Formatting(const {}, link))]),
      shape: _paragraph,
    ).text;
    expect(identical(text.pieces.single.formatting.link, link), isTrue);
  });

  test('a bare link after code is no link', () {
    final code = Formatting({TextFormat.code});
    final text = writableText(
      _text([TextPiece('x', code), TextPiece('www.example.com')]),
      shape: _paragraph,
    ).text;
    expect(text.pieces.last.formatting.link, isNull);
  });

  test('an edited line longer than the width wraps at single spaces', () {
    final words = List.filled(30, 'word').join(' ');
    final (source, _) = _written(_text([TextPiece(words)]));
    expect(source.split('\n').map((line) => line.length), [119, 29]);
    final narrow = writableText(
      _text([TextPiece(words)]),
      shape: const ParagraphShape(
        edited: (start: 0, end: 1 << 30),
        width: 60,
        prefix: 2,
      ),
    ).text;
    expect(narrow.pieces.whereType<SoftBreakPiece>().length, 2);
  });

  test('lines not edited never move', () {
    final long = List.filled(30, 'word').join(' ');
    final text = _text([TextPiece(long), SoftBreakPiece(), TextPiece('end')]);
    final edited = writableText(
      text,
      shape: ParagraphShape(
        edited: (start: long.length + 1, end: long.length + 4),
        width: 120,
        prefix: 0,
      ),
    ).text;
    expect(edited.pieces.whereType<SoftBreakPiece>().length, 1);
  });

  test('a heading in one line shows its breaks as spaces', () {
    expect(
      _written(
        _text([TextPiece('a'), HardBreakPiece(), TextPiece('b')]),
        shape: const HeadingShape(setext: false),
      ).$1,
      'a b',
    );
  });

  test('random text is written so that it reads back', () {
    final random = Random(7);
    const chars = [
      'a',
      'b',
      ' ',
      '*',
      '_',
      '`',
      '[',
      ']',
      '(',
      ')',
      '"',
      'w',
      '.',
      ':',
      '/',
      '@',
      '!',
      '\\',
      '<',
      '&',
      '~',
      '#',
    ];
    final formats = [
      Formatting.plain,
      _bold,
      Formatting({TextFormat.emphasis}),
      Formatting({TextFormat.strike, TextFormat.strong}),
      Formatting({TextFormat.code}),
    ];
    for (var round = 0; round < 400; round++) {
      final text = _text([
        for (final _ in Iterable<int>.generate(random.nextInt(6) + 1))
          switch (random.nextInt(8)) {
            0 => SoftBreakPiece(),
            1 => HardBreakPiece(),
            _ => TextPiece(
              [
                for (final _ in Iterable<int>.generate(random.nextInt(8) + 1))
                  chars[random.nextInt(chars.length)],
              ].join(),
              formats[random.nextInt(formats.length)],
            ),
          },
      ]);
      final writable = writableText(text, shape: _paragraph);
      expect(writable.text.text + writable.tail.text, text.text);
      expect(canWrite(writable.text), isTrue, reason: '$text');
      _written(text);
    }
  });
}
