/// The syntax of block marks at the start of a line: list items,
/// headings and quotes. The one owner of these rules.
library;

/// The kinds of list items.
enum ListKind {
  /// `- [ ] text`, with a box to check.
  checkbox,

  /// `- text`.
  bullet,

  /// `1. text`.
  numbered,
}

/// Where the parts of a list item's line are: the one reading of list
/// item syntax.
final class ItemSyntax {
  const ItemSyntax({
    required this.kind,
    required this.markStart,
    required this.textStart,
    this.markIndex = -1,
    this.bullet,
    this.number,
    this.delimiter,
  });

  /// The parts of [raw] if it is a list item.
  static ItemSyntax? of(String raw) {
    if (_thematicBreak.hasMatch(raw)) return null;
    if (_checkbox.firstMatch(raw) case final match?) {
      return ItemSyntax(
        kind: ListKind.checkbox,
        markStart: match[1]!.length,
        textStart: raw.length - match[3]!.length,
        markIndex: match[1]!.length + match[2]!.length + 1,
        bullet: match[2]!.trim(),
      );
    }
    if (_bullet.firstMatch(raw) case final match?) {
      return ItemSyntax(
        kind: ListKind.bullet,
        markStart: match[1]!.length,
        textStart: raw.length - match[3]!.length,
        bullet: match[2],
      );
    }
    if (_numbered.firstMatch(raw) case final match?) {
      return ItemSyntax(
        kind: ListKind.numbered,
        markStart: match[1]!.length,
        textStart: raw.length - match[4]!.length,
        number: int.parse(match[2]!),
        delimiter: match[3],
      );
    }
    return null;
  }

  /// `- [ ] text`, also with `*` or `+` bullets and `[x]` or `[X]`; as in
  /// GitHub Flavored Markdown, the box is followed by whitespace or the
  /// end of the line, so `- [x](url)` is a bulleted link.
  static final _checkbox = RegExp(
    r'^([ \t]*)([-*+][ \t]+)\[[ xX]\](?:[ \t]|$)(.*)$',
  );

  static final _bullet = RegExp(r'^([ \t]*)([-*+])(?:[ \t]+|$)(.*)$');

  static final _numbered = RegExp(r'^([ \t]*)(\d{1,9})([.)])(?:[ \t]+|$)(.*)$');

  /// `---`, `* * *` and the like: a line, not a list item.
  static final _thematicBreak = RegExp(
    r'^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$',
  );

  final ListKind kind;

  /// Start of the marker (bullet, number), after the indent.
  final int markStart;

  /// Start of the item text.
  final int textStart;

  /// Index of the character between `[` and `]` of a checkbox.
  final int markIndex;

  /// The bullet character of a checkbox or bullet item.
  final String? bullet;

  /// The number and the character after it of a numbered item.
  final int? number;
  final String? delimiter;
}

/// A list item line's kind, and where its marker (after the indent) and
/// its text start.
({ListKind kind, int markStart, int textStart})? itemMark(String line) =>
    switch (ItemSyntax.of(line)) {
      final item? => (
        kind: item.kind,
        markStart: item.markStart,
        textStart: item.textStart,
      ),
      null => null,
    };

/// A heading line's level and where its text starts after the `#` marks:
/// up to three spaces, one to six `#`, then whitespace or the line's end.
({int level, int textStart})? headingMark(String line) =>
    switch (_heading.firstMatch(line)) {
      final match? => (level: match[1]!.length, textStart: match.end),
      null => null,
    };

/// Where a quote line's text starts after its `>` marks; `null` if
/// [line] is no quote.
int? quoteTextStart(String line) => _quote.firstMatch(line)?.end;

/// Whether [line] starts a block of its own, which ends a paragraph above
/// it: a heading, quote, list item or line (`---`). A line that does not
/// continues that paragraph, also lazily, without the quote's `>`.
bool startsBlock(String line) =>
    headingMark(line) != null ||
    quoteTextStart(line) != null ||
    ItemSyntax.of(line) != null ||
    ItemSyntax._thematicBreak.hasMatch(line);

final _heading = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]+|$)');
final _quote = RegExp(r'^(?: {0,3}>[ \t]?)+');
