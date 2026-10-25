import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/read/inline_reader.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/tree/document_style.dart';
import 'package:truce_markdown/src/tree/inlines.dart';
import 'package:truce_markdown/src/visible/formatting.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';
import 'package:truce_markdown/src/write/inline/inline_writing.dart';
import 'package:truce_markdown/src/write/inline/span_syntax.dart';

import '../spec/spec_examples.dart';
import '../support/document_corpus.dart';

void main() {
  final paragraphs = [
    for (final text in [
      ...documentCorpus,
      for (final spec in ['commonmark-0.31.2.txt', 'gfm-0.29-extensions.txt'])
        for (final example in specExamples(spec)) example.markdown,
    ])
      for (final leaf in DocumentTree.read(
        text,
      ).leaves.whereType<ParagraphBlock>())
        if (_writable(visibleTextOf(leaf.text)) &&
            !_hasBareLink(leaf.text.inlines))
          leaf.text,
  ];

  test('random edits to inline text write text that reads as edited', () {
    for (final (index, start) in paragraphs.indexed) {
      final random = Random(index + 1000 * _seed);
      var inline = start;
      for (var step = 0; step < 40; step++) {
        final old = visibleTextOf(inline);
        final text = _randomEdit(random, old);
        if (text == null) continue;
        final source = inlineSource(
          old: inline.inlines,
          oldText: old,
          text: text,
          lines: TextLines.paragraph,
          style: const DocumentStyle(),
          definitions: const {},
        );
        expect(source, isNotNull, reason: 'from ${inline.source}\nfor $text');
        final read = readInlineText(source!);
        expect(
          visibleTextOf(read).looksLike(text),
          isTrue,
          reason: 'from ${inline.source}\nwrote $source\nfor $text',
        );
        inline = read;
      }
    }
  });

  test('typing words and styling whole words writes text', () {
    for (final (index, start) in paragraphs.indexed) {
      final random = Random(index + 1000 * _seed);
      var inline = start;
      for (var step = 0; step < 40; step++) {
        final old = visibleTextOf(inline);
        final text = _wordEdit(random, old);
        if (text == null) continue;
        final source = inlineSource(
          old: inline.inlines,
          oldText: old,
          text: text,
          lines: TextLines.paragraph,
          style: const DocumentStyle(),
          definitions: const {},
        );
        expect(source, isNotNull, reason: 'from ${inline.source}\nfor $text');
        inline = readInlineText(source!);
      }
    }
  });
}

/// [old] after typing a word or a space between words, or after styling
/// whole words, as a user does; `null` when it is no such edit.
VisibleText? _wordEdit(Random random, VisibleText old) {
  final words = [
    for (final match in RegExp(r'[A-Za-z0-9]+').allMatches(old.text)) match,
  ];
  if (words.isEmpty) return null;
  final word = words[random.nextInt(words.length)];
  final VisibleText text;
  if (random.nextBool()) {
    final at = random.nextBool() ? word.start : word.end;
    final typed = random.nextBool() ? 'new' : (at == word.end ? ', more' : 'x');
    final formatting = old.formattingAt(at > 0 ? at - 1 : 0);
    text = old.replaced(at, at, VisibleText([TextPiece(typed, formatting)]));
  } else {
    final last =
        words[min(words.length - 1, words.indexOf(word) + random.nextInt(3))];
    final format = [
      TextFormat.strong,
      TextFormat.emphasis,
      TextFormat.strike,
    ][random.nextInt(3)];
    final on = !old.formattingAt(word.start).has(format);
    text = old.reformatted(
      word.start,
      last.end,
      (formatting) => formatting.withFormat(format, on: on),
    );
  }
  return _writable(text) && canWrite(text) ? text : null;
}

final _seed = int.parse(Platform.environment['FUZZ_SEED'] ?? '0');

const _alphabet = r'ab  *_`~[]()!<>&#;\-+=.1|:';

/// [old] after a random insert, delete or style change; `null` when the
/// result is no text a command would make.
VisibleText? _randomEdit(Random random, VisibleText old) {
  final at = random.nextInt(old.length + 1);
  final VisibleText text;
  switch (random.nextInt(3)) {
    case 0:
      final typed = [
        for (var count = random.nextInt(4) + 1; count > 0; count--)
          _alphabet[random.nextInt(_alphabet.length)],
      ].join();
      final formatting = at > 0 ? old.formattingAt(at - 1) : Formatting.plain;
      text = old.replaced(at, at, VisibleText([TextPiece(typed, formatting)]));
    case 1:
      final to = min(old.length, at + random.nextInt(4) + 1);
      text = old.replaced(at, to, VisibleText.empty);
    default:
      final to = min(old.length, at + random.nextInt(6) + 1);
      final format = [
        TextFormat.strong,
        TextFormat.emphasis,
        TextFormat.strike,
        TextFormat.code,
      ][random.nextInt(4)];
      final on = !old
          .formattingAt(at.clamp(0, max(0, old.length - 1)))
          .has(format);
      text = old.reformatted(
        at,
        to,
        (formatting) => formatting.withFormat(format, on: on),
      );
  }
  return _writable(text) && canWrite(text) ? text : null;
}

/// Whether a command could leave a leaf with [text]: no space at its
/// end or beside a soft break, no break at its ends, spans that fit,
/// code only around text.
bool _writable(VisibleText text) {
  if (text.isEmpty) return false;
  final shown = text.text;
  if (RegExp(r'[ \t]$').hasMatch(shown)) return false;
  final pieces = text.pieces;
  if (pieces.first is! TextPiece && pieces.first is! ObjectPiece) return false;
  if (pieces.last is! TextPiece && pieces.last is! ObjectPiece) return false;
  for (final (at, piece) in text.placedPieces) {
    if (piece is SoftBreakPiece &&
        (RegExp(r'[ \t]').hasMatch(charAround(shown, at - 1)) ||
            RegExp(r'[ \t]').hasMatch(charAround(shown, at + 1)))) {
      return false;
    }
    if (piece is! TextPiece && piece.formatting.has(TextFormat.code)) {
      return false;
    }
  }
  return spansFit(text);
}

bool _hasBareLink(List<Inline> inlines) => inlines.any(
  (inline) => switch (inline) {
    LinkInline(style: LinkStyle.extendedAutolink) => true,
    ContainerInline(:final children) => _hasBareLink(children),
    _ => false,
  },
);
