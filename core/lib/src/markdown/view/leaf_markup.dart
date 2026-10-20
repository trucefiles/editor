import '../inline/inline_reader.dart';
import '../inline/inlines.dart';
import '../tree/block_starts.dart';
import '../tree/blocks.dart';
import 'markup.dart';

/// What kind of block a view shows, as its markup and editing need it.
enum LeafKind {
  paragraph,
  heading,
  code,
  html,
  table,
  rule,
  definitions,
  frontMatter,
  blank;

  /// The kind of [leaf].
  static LeafKind of(LeafBlock leaf) => switch (leaf) {
    ParagraphBlock() => paragraph,
    HeadingBlock() => heading,
    CodeBlock() => code,
    HtmlBlock() => html,
    TableBlock() => table,
    RuleBlock() => rule,
    DefinitionsBlock() => definitions,
    FrontMatterBlock() => frontMatter,
    BlankBlock() => blank,
  };

  /// Whether its text is read for inline marks (emphasis, links), which
  /// format buttons can add.
  bool get hasInlines => this == paragraph || this == heading || this == blank;
}

/// The markup of [text], the text of a block of [kind] (a block read as
/// [leaf], whose text the user may have changed since): its block marks
/// and, where it has them, inline marks, with reference links looked up
/// in [definitions]. The one owner of how Markdown shows.
List<MarkupSpan> leafMarkup(
  String text,
  LeafKind kind, {
  required LeafBlock leaf,
  required Map<String, LinkDefinition> definitions,
}) {
  List<MarkupSpan> inlines([int start = 0, int? end]) => [
    ..._lineEndBackslashes(text, start, end ?? text.length),
    ..._inlineMarkup(
      readInlines(text, start: start, end: end, definitions: definitions),
    ),
  ];
  MarkupSpan whole(Markup markup) => MarkupSpan(markup, 0, text.length);
  return switch (kind) {
    LeafKind.paragraph || LeafKind.blank => inlines(),
    LeafKind.heading => switch (leaf) {
      HeadingBlock(setext: true, :final level) => _setextMarkup(
        text,
        level,
        inlines,
      ),
      _ => _atxMarkup(text, inlines),
    },
    LeafKind.code => [
      whole(const CodeBlockMarkup()),
      if (leaf case CodeBlock(fenced: true, :final closed)) ...[
        MarkupSpan(const DimmedMarkup(), 0, _lineEnd(text, 0)),
        if (closed && text.contains('\n'))
          MarkupSpan(
            const DimmedMarkup(),
            text.lastIndexOf('\n') + 1,
            text.length,
          ),
      ],
    ],
    LeafKind.html || LeafKind.table => [whole(const CodeBlockMarkup())],
    LeafKind.rule || LeafKind.definitions => [whole(const DimmedMarkup())],
    LeafKind.frontMatter => [
      whole(const CodeBlockMarkup()),
      whole(const DimmedMarkup()),
    ],
  };
}

/// An ATX heading: `#` marks before, optional `#` marks after.
List<MarkupSpan> _atxMarkup(
  String text,
  List<MarkupSpan> Function([int start, int? end]) inlines,
) {
  final line = text.substring(0, _lineEnd(text, 0));
  final indent = line.length - line.trimLeft().length;
  final open = atxHeading.matchAsPrefix(line, indent);
  if (open == null) return inlines();
  final level = open[0]!.trim().length;
  final closing = RegExp(r'(?:^|[ \t]+)#+[ \t]*$')
      .firstMatch(line.substring(open.end));
  final end = closing == null ? line.length : open.end + closing.start;
  return [
    MarkupSpan(HeadingMarkup(level), 0, text.length),
    MarkupSpan(const SyntaxMarkup(), 0, open.end),
    ...inlines(open.end, end),
    if (end < line.length) MarkupSpan(const SyntaxMarkup(), end, line.length),
  ];
}

/// A heading of lines over an underline of `=` or `-`.
List<MarkupSpan> _setextMarkup(
  String text,
  int level,
  List<MarkupSpan> Function([int start, int? end]) inlines,
) {
  final underline = text.lastIndexOf('\n') + 1;
  if (underline == 0 ||
      !setextUnderline.hasMatch(text.substring(underline).trimLeft())) {
    return inlines();
  }
  return [
    MarkupSpan(HeadingMarkup(level), 0, underline - 1),
    ...inlines(0, underline - 1),
    MarkupSpan(const SyntaxMarkup(), underline, text.length),
  ];
}

/// A backslash at the end of a line: a hard break, or one being typed at
/// a block's end. Hidden as syntax, so lines read as text.
Iterable<MarkupSpan> _lineEndBackslashes(String text, int start, int end) => [
  for (final match in RegExp(
    r'\\(?=\n|$)',
  ).allMatches(text.substring(0, end), start))
    MarkupSpan(const SyntaxMarkup(), match.start, match.end),
];

int _lineEnd(String text, int from) => switch (text.indexOf('\n', from)) {
  -1 => text.length,
  final end => end,
};

/// The markup of [inlines], with source ranges as they have.
List<MarkupSpan> _inlineMarkup(List<Inline> inlines) => [
  for (final inline in inlines) ..._markupOf(inline),
];

List<MarkupSpan> _markupOf(Inline inline) => switch (inline) {
  // A backslash escape: the backslash is syntax. A character reference
  // takes at least four characters.
  TextInline(:final start, :final end, :final literal)
      when end - start == 2 && literal.length == 1 =>
    [MarkupSpan(const SyntaxMarkup(), start, start + 1)],
  TextInline(:final start, :final end, :final literal)
      when end - start != literal.length =>
    [MarkupSpan(EntityMarkup(literal), start, end)],
  TextInline() || SoftBreakInline() || HardBreakInline() => const [],
  CodeInline(:final start, :final end, :final codeStart, :final codeEnd) => [
    MarkupSpan(const CodeMarkup(), start, end),
    MarkupSpan(const SyntaxMarkup(), start, codeStart),
    MarkupSpan(const SyntaxMarkup(), codeEnd, end),
  ],
  HtmlInline(:final start, :final end) => [
    MarkupSpan(const DimmedMarkup(), start, end),
  ],
  ImageInline(:final start, :final end, :final destination, :final children) =>
    [
      MarkupSpan(ImageMarkup(destination, plainTextOf(children)), start, end),
      ..._wrapped(inline, const DimmedMarkup()),
    ],
  EmphasisInline() => _wrapped(inline, const ItalicMarkup()),
  StrongInline() => _wrapped(inline, const BoldMarkup()),
  StrikeInline() => _wrapped(inline, const StrikeMarkup()),
  LinkInline(:final destination) => _wrapped(inline, LinkMarkup(destination)),
};

/// [inline]'s [markup] on its inner text, its marks as syntax, and the
/// markup of what it holds.
List<MarkupSpan> _wrapped(ContainerInline inline, Markup markup) => [
  if (inline.innerEnd > inline.innerStart)
    MarkupSpan(markup, inline.innerStart, inline.innerEnd),
  if (inline.innerStart > inline.start)
    MarkupSpan(const SyntaxMarkup(), inline.start, inline.innerStart),
  if (inline.end > inline.innerEnd)
    MarkupSpan(const SyntaxMarkup(), inline.innerEnd, inline.end),
  ..._inlineMarkup(inline.children),
];
