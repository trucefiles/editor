/// Inline content of a leaf as CommonMark and GitHub Flavored Markdown
/// read it: a tree of spans with their source ranges in the leaf's text,
/// so an editor can style the text in place and show or hide its marks.
library;

/// One span of inline content, from [start] to [end] in its leaf's text.
sealed class Inline {
  const Inline(this.start, this.end);

  final int start;
  final int end;
}

/// Text, which may read differently from its source: an escape (`\*`)
/// or character reference (`&amp;`) stands for the character [literal]
/// holds.
final class TextInline extends Inline {
  const TextInline(super.start, super.end, this.literal);

  final String literal;
}

/// A line break that shows as a space.
final class SoftBreakInline extends Inline {
  const SoftBreakInline(super.start, super.end);
}

/// A line break that shows as one: a `\` or two spaces at a line's end.
final class HardBreakInline extends Inline {
  const HardBreakInline(super.start, super.end);
}

/// A code span; its code is [literal], read from [codeStart] to
/// [codeEnd].
final class CodeInline extends Inline {
  const CodeInline(
    super.start,
    super.end, {
    required this.literal,
    required this.codeStart,
    required this.codeEnd,
  });

  final String literal;
  final int codeStart;
  final int codeEnd;
}

/// Raw HTML, kept as written.
final class HtmlInline extends Inline {
  const HtmlInline(super.start, super.end);
}

/// A span that holds other spans between its opening and closing marks:
/// its [children] lie from [innerStart] to [innerEnd].
sealed class ContainerInline extends Inline {
  const ContainerInline(
    super.start,
    super.end, {
    required this.innerStart,
    required this.innerEnd,
    required this.children,
  });

  final int innerStart;
  final int innerEnd;
  final List<Inline> children;
}

/// `*text*` or `_text_`.
final class EmphasisInline extends ContainerInline {
  const EmphasisInline(
    super.start,
    super.end, {
    required super.innerStart,
    required super.innerEnd,
    required super.children,
  });
}

/// `**text**` or `__text__`.
final class StrongInline extends ContainerInline {
  const StrongInline(
    super.start,
    super.end, {
    required super.innerStart,
    required super.innerEnd,
    required super.children,
  });
}

/// `~text~` or `~~text~~`.
final class StrikeInline extends ContainerInline {
  const StrikeInline(
    super.start,
    super.end, {
    required super.innerStart,
    required super.innerEnd,
    required super.children,
  });
}

/// A link: `[text](url)`, a reference link, `<url>` or a bare url; its
/// [children] are its text.
final class LinkInline extends ContainerInline {
  const LinkInline(
    super.start,
    super.end, {
    required super.innerStart,
    required super.innerEnd,
    required super.children,
    required this.destination,
    this.title = '',
  });

  /// Where it leads, as written (unescaped), with a scheme added to a
  /// bare `www.` or email address.
  final String destination;
  final String title;
}

/// An image: `![alt](url)` or a reference image; its [children] are its
/// description.
final class ImageInline extends ContainerInline {
  const ImageInline(
    super.start,
    super.end, {
    required super.innerStart,
    required super.innerEnd,
    required super.children,
    required this.destination,
    this.title = '',
  });

  final String destination;
  final String title;
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
