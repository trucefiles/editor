/// Inline content of a text leaf as CommonMark and GitHub Flavored
/// Markdown read it: a tree of nodes, each holding its exact source, so
/// a writer copies untouched nodes byte for byte. Nodes hold no
/// positions; a node's source is its children's sources between its own
/// marks.
library;

import 'package:truce_core/truce_core.dart' show anyLineBreak;

/// The inline content of one leaf (or table cell): the [inlines] read,
/// and the source around them that is no inline content: a heading's
/// marks, whitespace the reader trims.
final class InlineText {
  InlineText(this.before, List<Inline> inlines, this.after)
    : inlines = List.unmodifiable(inlines);

  static final empty = InlineText('', const [], '');

  final String before;
  final List<Inline> inlines;
  final String after;

  /// The source of [inlines] alone.
  late final String inlineSource = inlines.map((node) => node.source).join();

  /// The whole source: [before], the inlines, [after].
  late final String source = '$before$inlineSource$after';
}

/// One node of inline content.
sealed class Inline {
  const Inline();

  /// Its source, exactly as in the file.
  String get source;
}

/// Text: a plain run that reads as written, or one escaped character
/// (`\*`) or character reference (`&amp;`) whose [literal] differs from
/// its [source].
final class TextInline extends Inline {
  const TextInline(this.literal, [String? source]) : source = source ?? literal;

  final String literal;

  @override
  final String source;

  /// Whether it reads as written.
  bool get isPlain => literal == source;
}

/// A line break that shows as a space; its source is the break, the
/// spaces before it and the indent after it.
final class SoftBreakInline extends Inline {
  const SoftBreakInline(this.source);

  @override
  final String source;
}

/// How a hard line break is written.
enum HardBreakStyle {
  /// `\` at the line's end.
  backslash,

  /// Two or more spaces at the line's end.
  spaces,
}

/// A line break that shows as one.
final class HardBreakInline extends Inline {
  const HardBreakInline(this.source);

  @override
  final String source;

  HardBreakStyle get style => source.startsWith(r'\')
      ? HardBreakStyle.backslash
      : HardBreakStyle.spaces;
}

/// A code span: its backtick runs and the code between; [literal] is the
/// code as it shows.
final class CodeInline extends Inline {
  const CodeInline(this.source, this.literal);

  @override
  final String source;

  final String literal;
}

/// Raw HTML, kept as written.
final class HtmlInline extends Inline {
  const HtmlInline(this.source);

  @override
  final String source;
}

/// A node that holds other nodes between its [open] and [close] marks.
sealed class ContainerInline extends Inline {
  ContainerInline(this.open, List<Inline> children, this.close)
    : children = List.unmodifiable(children);

  final String open;
  final List<Inline> children;
  final String close;

  @override
  late final String source =
      '$open${children.map((child) => child.source).join()}$close';
}

/// `*text*` or `_text_`.
final class EmphasisInline extends ContainerInline {
  EmphasisInline(super.open, super.children, super.close);
}

/// `**text**` or `__text__`.
final class StrongInline extends ContainerInline {
  StrongInline(super.open, super.children, super.close);
}

/// `~text~` or `~~text~~`.
final class StrikeInline extends ContainerInline {
  StrikeInline(super.open, super.children, super.close);
}

/// How a link is written.
enum LinkStyle {
  /// `[text](url "title")`.
  inline,

  /// `[text][label]`, `[text][]` or `[text]`, with a definition elsewhere.
  reference,

  /// `<url>` or `<email>`.
  autolink,

  /// A bare `www.` or scheme url or an email address, as GFM reads it.
  extendedAutolink,
}

/// A link; its children are its text.
final class LinkInline extends ContainerInline {
  LinkInline(
    super.open,
    super.children,
    super.close, {
    required this.destination,
    required this.style,
    this.title = '',
  });

  /// Where it leads, unescaped; a scheme added to a bare `www.` or email
  /// address.
  final String destination;
  final String title;
  final LinkStyle style;
}

/// An image; its children are its description.
final class ImageInline extends ContainerInline {
  ImageInline(
    super.open,
    super.children,
    super.close, {
    required this.destination,
    this.title = '',
  });

  final String destination;
  final String title;

  /// Its description as plain text.
  String get description => plainTextOf(children);
}

/// The plain text [inlines] show, e.g. an image's description.
String plainTextOf(List<Inline> inlines) => inlines
    .map(
      (inline) => switch (inline) {
        TextInline(:final literal) => literal,
        SoftBreakInline() || HardBreakInline() => ' ',
        CodeInline(:final literal) => literal,
        HtmlInline() => '',
        ContainerInline(:final children) => plainTextOf(children),
      },
    )
    .join();

/// [inline] as written in one line: its line ends as spaces, its line
/// breaks as space text; the same node if it is in one line.
Inline inOneLine(Inline inline) {
  List<Inline> children(ContainerInline container) =>
      container.children.map(inOneLine).toList();
  return switch (inline) {
    _ when !inline.source.contains(anyLineBreak) => inline,
    SoftBreakInline() || HardBreakInline() => const TextInline(' '),
    TextInline() => inline,
    CodeInline(:final source, :final literal) => CodeInline(
      spacedLineEnds(source),
      literal,
    ),
    HtmlInline(:final source) => HtmlInline(spacedLineEnds(source)),
    EmphasisInline(:final open, :final close) => EmphasisInline(
      open,
      children(inline),
      close,
    ),
    StrongInline(:final open, :final close) => StrongInline(
      open,
      children(inline),
      close,
    ),
    StrikeInline(:final open, :final close) => StrikeInline(
      open,
      children(inline),
      close,
    ),
    LinkInline(:final open, :final close) => LinkInline(
      open,
      children(inline),
      spacedLineEnds(close),
      destination: inline.destination,
      style: inline.style,
      title: spacedLineEnds(inline.title),
    ),
    ImageInline(:final open, :final close) => ImageInline(
      open,
      children(inline),
      spacedLineEnds(close),
      destination: inline.destination,
      title: spacedLineEnds(inline.title),
    ),
  };
}

/// [text] with its line ends as spaces.
String spacedLineEnds(String text) => text.replaceAll(anyLineBreak, ' ');

/// [inlines] and every inline within them, outermost first.
Iterable<Inline> inlinesWithin(List<Inline> inlines) => inlines.expand(
  (inline) => [
    inline,
    if (inline is ContainerInline) ...inlinesWithin(inline.children),
  ],
);
