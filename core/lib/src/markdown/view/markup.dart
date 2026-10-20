/// How a range of a block's text shows, by its Markdown.
sealed class Markup {
  const Markup();
}

/// Markdown syntax characters, e.g. `**`, `# ` or `](url)`: hidden where
/// the text shows formatted, dimmed where every character shows.
final class SyntaxMarkup extends Markup {
  const SyntaxMarkup();
}

/// Text that shows as [text] where the text shows formatted, e.g. a
/// character reference (`&amp;` as `&`) or an image (as one object).
sealed class ReplacedMarkup extends Markup {
  const ReplacedMarkup();

  /// What shows instead of the range.
  String get text;
}

/// A character reference: shows as the [text] it stands for.
final class EntityMarkup extends ReplacedMarkup {
  const EntityMarkup(this.text);

  @override
  final String text;

  @override
  bool operator ==(Object other) => other is EntityMarkup && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// An image: shows as one object, the image at [url] described by [alt].
final class ImageMarkup extends ReplacedMarkup {
  const ImageMarkup(this.url, this.alt);

  /// Where the image is, as written (unescaped).
  final String url;
  final String alt;

  /// The object replacement character, where the image shows.
  @override
  String get text => '\uFFFC';

  @override
  bool operator ==(Object other) =>
      other is ImageMarkup && other.url == url && other.alt == alt;

  @override
  int get hashCode => Object.hash(url, alt);
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

/// A code block's text, or other text shown as source (a table being
/// edited, HTML).
final class CodeBlockMarkup extends Markup {
  const CodeBlockMarkup();
}

final class LinkMarkup extends Markup {
  const LinkMarkup(this.url);

  /// Where the link leads, as written (unescaped).
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
