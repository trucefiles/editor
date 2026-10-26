import '../../tree/blocks.dart';
import '../../tree/inlines.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../../write/inline/inline_writing.dart';
import 'autolinks.dart';
import 'references.dart';
import 'representable_spans.dart';
import 'whitespace.dart';
import 'wrapping.dart';

/// How a text leaf writes its lines.
sealed class TextShape {
  const TextShape();
}

/// A paragraph whose lines in [edited] wrap at [width], after [prefix]
/// columns of its containers' marks.
final class ParagraphShape extends TextShape {
  const ParagraphShape({
    required this.edited,
    required this.width,
    required this.prefix,
  });

  final ({int start, int end}) edited;
  final int width;
  final int prefix;
}

/// A heading, written in one line unless [setext].
final class HeadingShape extends TextShape {
  const HeadingShape({required this.setext});

  final bool setext;
}

/// What a text leaf writes of the text it [shown]s, and the [tail] it
/// shows after that, which Markdown would drop at the leaf's end. The
/// text reads back as written: whitespace only where Markdown keeps it,
/// references only to definitions that stay (else inline), spans that
/// delimiters can write, autolinks leading where their text
/// says, bare links where GitHub Flavored
/// Markdown reads them, edited paragraph lines wrapped. Its characters
/// are those shown, except that a heading in one line shows its breaks
/// as spaces.
({VisibleText text, VisibleText tail}) writableText(
  VisibleText shown, {
  required TextShape shape,
  Map<String, LinkDefinition> definitions = const {},
}) {
  final lines = switch (shape) {
    HeadingShape(setext: false) => TextLines.atxHeading,
    _ => TextLines.paragraph,
  };
  final defined = withDefinedReferences(shown, definitions);
  final (:text, :tail) = withoutTail(switch (shape) {
    HeadingShape(setext: false) => _breaksAsSpaces(defined),
    _ => defined,
  });
  final spans = representableSpans(
    withoutAutolinks(
      withAngleAutolinks(spanEdgesTrimmed(softBreaksBetweenWords(text))),
    ),
    lines: lines,
    definitions: definitions,
  );
  final linked = withAutolinks(spans, was: text);
  // Bare links whose text would read as more than a link are written as
  // text, escaped so that it reads as text.
  final written = canWrite(linked, lines: lines, definitions: definitions)
      ? linked
      : spans;
  return (
    text: switch (shape) {
      ParagraphShape(:final edited, :final width, :final prefix) => wrapped(
        written,
        edited: (
          start: edited.start.clamp(0, written.length),
          end: edited.end.clamp(0, written.length),
        ),
        width: width,
        prefix: prefix,
      ),
      HeadingShape() => written,
    },
    tail: tail,
  );
}

/// [text] in one line: its breaks, and the line ends inside its
/// objects and links' marks, as spaces.
VisibleText _breaksAsSpaces(VisibleText text) {
  final links = {
    for (final piece in text.pieces)
      if (piece.formatting.link case final link?
          when link.read?.source.contains(lineEnd) ?? false)
        link: LinkMark(
          destination: link.destination,
          title: spacedLineEnds(link.title),
          style: LinkStyle.inline,
        ),
  };
  Formatting oneLine(Formatting formatting) => switch (formatting.link) {
    final link? when links.containsKey(link) => formatting.withLink(
      links[link],
    ),
    _ => formatting,
  };
  return VisibleText([
    for (final piece in text.pieces)
      switch (piece) {
        SoftBreakPiece() ||
        HardBreakPiece() => TextPiece(' ', oneLine(piece.formatting)),
        ObjectPiece(:final inline, :final formatting)
            when inline.source.contains(lineEnd) =>
          ObjectPiece(inOneLine(inline), oneLine(formatting)),
        _ => piece.withFormatting(oneLine(piece.formatting)),
      },
  ]);
}
