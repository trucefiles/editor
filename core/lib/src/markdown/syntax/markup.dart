/// How a range of a line's text shows, by its Markdown.
sealed class Markup {
  const Markup();
}

/// Markdown syntax characters, e.g. `**`, `# ` or `](url)`: hidden where
/// the text shows formatted, dimmed where every character shows.
final class SyntaxMarkup extends Markup {
  const SyntaxMarkup();
}

/// Shown dimmed wherever the text shows, e.g. a code fence.
final class DimmedMarkup extends Markup {
  const DimmedMarkup();
}

final class BoldMarkup extends Markup {
  const BoldMarkup();
}

final class ItalicMarkup extends Markup {
  const ItalicMarkup();
}

final class StrikeMarkup extends Markup {
  const StrikeMarkup();
}

/// Inline code.
final class CodeMarkup extends Markup {
  const CodeMarkup();
}

/// A line inside a fenced code block, or a fence.
final class CodeBlockMarkup extends Markup {
  const CodeBlockMarkup();
}

final class LinkMarkup extends Markup {
  const LinkMarkup(this.url);

  /// The link target as written.
  final String url;

  @override
  bool operator ==(Object other) => other is LinkMarkup && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

final class HeadingMarkup extends Markup {
  const HeadingMarkup(this.level);

  /// 1 to 6.
  final int level;

  @override
  bool operator ==(Object other) =>
      other is HeadingMarkup && other.level == level;

  @override
  int get hashCode => level.hashCode;
}

final class QuoteMarkup extends Markup {
  const QuoteMarkup();
}

/// A list bullet character (`-`, `*`, `+`), drawn as a bullet where the
/// text shows formatted.
final class BulletMarkup extends Markup {
  const BulletMarkup();
}

/// [markup] on the text from [start] to [end] (exclusive).
final class MarkupSpan {
  const MarkupSpan(this.markup, this.start, this.end);

  final Markup markup;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is MarkupSpan &&
      other.markup == markup &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(markup, start, end);

  @override
  String toString() => '$markup($start, $end)';
}
