import '../document_tree.dart';
import '../tree/blocks.dart';
import '../tree/inlines.dart';

/// What a stretch of a line is, for Markdown edit to show it so: its
/// marks, or text that reads formatted.
sealed class Highlight {
  const Highlight();
}

/// Kinds of stretches besides headings and links.
enum TextHighlight implements Highlight {
  /// Markdown's own marks: `#`, `**`, `>`, a list marker, a fence.
  mark,
  strong,
  emphasis,
  strike,

  /// Code, in a code span or block.
  code,

  /// Kept as written, not read: HTML, link definitions, front matter.
  raw,
}

/// A heading of [level] 1 to 6: its text and its marks.
final class HeadingHighlight implements Highlight {
  const HeadingHighlight(this.level);

  final int level;

  @override
  bool operator ==(Object other) =>
      other is HeadingHighlight && other.level == level;

  @override
  int get hashCode => Object.hash(HeadingHighlight, level);
}

/// A link's or image's text, leading to [destination].
final class LinkHighlight implements Highlight {
  const LinkHighlight(this.destination);

  final String destination;

  @override
  bool operator ==(Object other) =>
      other is LinkHighlight && other.destination == destination;

  @override
  int get hashCode => Object.hash(LinkHighlight, destination);
}

/// [highlight] from [start] to [end] in a line.
typedef HighlightSpan = ({int start, int end, Highlight highlight});

/// The highlights of each of [tree]'s lines, outer ones first: stretches
/// may lie within others (bold text in a link).
List<List<HighlightSpan>> highlightsOf(DocumentTree tree) {
  final byLeaf = {for (final leaf in tree.leaves) leaf: _leafHighlights(leaf)};
  return [
    for (final (index, line) in tree.lines.indexed)
      switch (tree.leafOf(index)) {
        final leaf? => byLeaf[leaf]![index]!,
        null => _layoutLine(line),
      },
  ];
}

/// A line in no leaf (blank, `>` or an empty item's marker): marks
/// only.
List<HighlightSpan> _layoutLine(String text) {
  final start = text.length - text.trimLeft().length;
  final end = text.trimRight().length;
  return [
    if (end > start) (start: start, end: end, highlight: TextHighlight.mark),
  ];
}

/// The highlights of each line of [leaf]: its containers' parts as
/// marks, then its own part's.
Map<int, List<HighlightSpan>> _leafHighlights(LeafBlock leaf) {
  final own = _contentHighlights(leaf);
  return {
    for (final (index, line) in leaf.lines.indexed)
      line.index: [
        for (final part in line.prefix)
          if (part.end > part.start)
            (start: part.start, end: part.end, highlight: TextHighlight.mark),
        ...own[index],
      ],
  };
}

/// The highlights of the content of each of [leaf]'s lines, in line
/// offsets.
List<List<HighlightSpan>> _contentHighlights(LeafBlock leaf) {
  final lines = leaf.lines;
  List<HighlightSpan> whole(SourceLine line, Highlight highlight) => [
    if (line.text.length > line.contentStart)
      (start: line.contentStart, end: line.text.length, highlight: highlight),
  ];
  return switch (leaf) {
    TextLeaf(:final text) => _inLines(lines, _inlineSpans(text, leaf)),
    CodeBlock(:final fenced, :final closed) => [
      for (final (index, line) in lines.indexed)
        whole(
          line,
          fenced && (index == 0 || (closed && index == lines.length - 1))
              ? TextHighlight.mark
              : TextHighlight.code,
        ),
    ],
    HtmlBlock() || DefinitionsBlock() || FrontMatterBlock() => [
      for (final line in lines) whole(line, TextHighlight.raw),
    ],
    RuleBlock() => [for (final line in lines) whole(line, TextHighlight.mark)],
    TableBlock() => [
      for (final (index, line) in lines.indexed)
        index == 1
            ? whole(line, TextHighlight.mark)
            : [
                for (final (offset, char) in line.text.split('').indexed)
                  if (char == '|' && offset >= line.contentStart)
                    (
                      start: offset,
                      end: offset + 1,
                      highlight: TextHighlight.mark,
                    ),
              ],
    ],
  };
}

/// [spans] in a leaf's content (its lines' parts joined by `\n`) as
/// spans in each of [lines].
List<List<HighlightSpan>> _inLines(
  List<SourceLine> lines,
  List<HighlightSpan> spans,
) {
  final starts = lines.fold(
    (next: 0, starts: <int>[]),
    (done, line) => (
      next: done.next + line.content.length + 1,
      starts: [...done.starts, done.next],
    ),
  ).starts;
  return [
    for (final (index, line) in lines.indexed)
      [
        for (final span in spans)
          if (span.end > starts[index] &&
              span.start < starts[index] + line.content.length)
            (
              start:
                  line.contentStart +
                  (span.start - starts[index]).clamp(0, line.content.length),
              end:
                  line.contentStart +
                  (span.end - starts[index]).clamp(0, line.content.length),
              highlight: span.highlight,
            ),
      ],
  ];
}

/// The highlights of [text], a text leaf's inline content, in its
/// source: a heading and its marks, then each inline's.
List<HighlightSpan> _inlineSpans(InlineText text, TextLeaf leaf) {
  final before = text.before.length;
  final end = before + text.inlineSource.length;
  return [
    if (leaf case HeadingBlock(:final level))
      (
        start: 0,
        end: end + text.after.length,
        highlight: HeadingHighlight(level),
      ),
    if (before > 0) (start: 0, end: before, highlight: TextHighlight.mark),
    if (text.after.isNotEmpty)
      (start: end, end: end + text.after.length, highlight: TextHighlight.mark),
    ..._inlines(text.inlines, before),
  ];
}

/// The highlights of [inlines], whose source starts at [start].
List<HighlightSpan> _inlines(List<Inline> inlines, int start) => inlines.fold(
  (at: start, spans: <HighlightSpan>[]),
  (done, inline) => (
    at: done.at + inline.source.length,
    spans: [...done.spans, ..._inline(inline, done.at)],
  ),
).spans;

/// The highlights of [inline], whose source starts at [start].
List<HighlightSpan> _inline(Inline inline, int start) {
  final end = start + inline.source.length;
  HighlightSpan span(int from, int to, Highlight highlight) =>
      (start: from, end: to, highlight: highlight);
  return switch (inline) {
    TextInline() || SoftBreakInline() => const [],
    HardBreakInline(:final style) => [
      if (style == HardBreakStyle.backslash)
        span(start, start + 1, TextHighlight.mark),
    ],
    CodeInline(:final source) => [
      span(start, end, TextHighlight.code),
      ..._codeMarks(source, start),
    ],
    HtmlInline() => [span(start, end, TextHighlight.raw)],
    ContainerInline(:final open, :final children, :final close) => [
      if (_highlightOf(inline) case final highlight?)
        span(start + open.length, end - close.length, highlight),
      if (open.isNotEmpty) span(start, start + open.length, TextHighlight.mark),
      if (close.isNotEmpty) span(end - close.length, end, TextHighlight.mark),
      ..._inlines(children, start + open.length),
    ],
  };
}

/// The backtick runs of a code span, whose [source] starts at [start].
List<HighlightSpan> _codeMarks(String source, int start) {
  final ticks = source.length - source.replaceFirst(RegExp('^`+'), '').length;
  return [
    (start: start, end: start + ticks, highlight: TextHighlight.mark),
    (
      start: start + source.length - ticks,
      end: start + source.length,
      highlight: TextHighlight.mark,
    ),
  ];
}

Highlight? _highlightOf(ContainerInline inline) => switch (inline) {
  StrongInline() => TextHighlight.strong,
  EmphasisInline() => TextHighlight.emphasis,
  StrikeInline() => TextHighlight.strike,
  LinkInline(:final destination) ||
  ImageInline(:final destination) => LinkHighlight(destination),
};
