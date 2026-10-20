/// The syntax of block marks at the start of a line: list items,
/// headings and quotes. The one owner of these rules.
library;

import 'dart:math';

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
    required this.contentStart,
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
      final markStart = match[1]!.length;
      return ItemSyntax(
        kind: ListKind.checkbox,
        markStart: markStart,
        contentStart: _contentStart(
          markStart + 1,
          markStart + match[2]!.length,
        ),
        textStart: raw.length - match[3]!.length,
        markIndex: match[1]!.length + match[2]!.length + 1,
        bullet: match[2]!.trim(),
      );
    }
    if (_bullet.firstMatch(raw) case final match?) {
      final markStart = match[1]!.length;
      final textStart = raw.length - match[3]!.length;
      return ItemSyntax(
        kind: ListKind.bullet,
        markStart: markStart,
        contentStart: _contentStart(markStart + 1, textStart),
        textStart: textStart,
        bullet: match[2],
      );
    }
    if (_numbered.firstMatch(raw) case final match?) {
      final markStart = match[1]!.length;
      final textStart = raw.length - match[4]!.length;
      return ItemSyntax(
        kind: ListKind.numbered,
        markStart: markStart,
        contentStart: _contentStart(
          markStart + match[2]!.length + 1,
          textStart,
        ),
        textStart: textStart,
        number: int.parse(match[2]!),
        delimiter: match[3],
      );
    }
    return null;
  }

  /// Where the content starts after a marker ending at [markEnd], with
  /// the item's text or box at [next]; see [contentStart].
  static int _contentStart(int markEnd, int next) => switch (next - markEnd) {
    final spaces when spaces >= 1 && spaces <= 4 => next,
    _ => markEnd + 1,
  };

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

  /// Where the item's content starts, as Markdown counts it: after the
  /// marker and the one to four spaces after it, or one if there are none
  /// or more (then the rest is the content's own). Lines under the item
  /// are indented at least this far. A box is content.
  final int contentStart;

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
/// it: a heading, quote, list item, line (`---`) or code fence. A line
/// that does not continues that paragraph, also lazily, without the
/// quote's `>` or the item's indent.
bool startsBlock(String line) =>
    headingMark(line) != null ||
    quoteTextStart(line) != null ||
    ItemSyntax.of(line) != null ||
    ItemSyntax._thematicBreak.hasMatch(line) ||
    fenceOf(line) != null;

/// The fence that opens a fenced code block on [line] (```` ``` ```` or
/// `~~~`, three or more), after up to three spaces; `null` if none does.
String? fenceOf(String line) => _fence.firstMatch(line)?.group(1);

/// Whether [line] closes a code block opened with [fence]: a fence of the
/// same character, at least as long, alone on its line.
bool closesFence(String fence, String line) => switch (fenceOf(line)) {
  final closing? =>
    closing[0] == fence[0] &&
        closing.length >= fence.length &&
        line.trim() == closing,
  null => false,
};

/// The level of the heading that [line] underlines when it is right below
/// a paragraph's text: 1 for `===`, 2 for `---`; `null` if it is no such
/// underline.
int? underlineLevel(String line) => switch (_underline.firstMatch(line)) {
  final match? => match[1]![0] == '=' ? 1 : 2,
  null => null,
};

/// The column [text] ends at, from the start of its line: a tab goes on
/// to the next multiple of four, as Markdown counts.
int columnsOf(String text) => text.runes.fold(
  0,
  (column, rune) => rune == 0x09 ? column + 4 - column % 4 : column + 1,
);

/// [line] from [column] on, as a block inside a container that starts
/// there sees it: without the leading whitespace up to that column; a tab
/// that reaches past it leaves the rest of its width as spaces.
String restFrom(String line, int column) {
  final leading = _leadingSpace.firstMatch(line)!.end;
  final end = Iterable.generate(leading + 1, (index) => index).firstWhere(
    (index) =>
        index == leading || columnsOf(line.substring(0, index)) >= column,
  );
  final reached = columnsOf(line.substring(0, end));
  return '${' ' * max(0, reached - column)}${line.substring(end)}';
}

final _leadingSpace = RegExp(r'^[ \t]*');
final _heading = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]+|$)');
final _quote = RegExp(r'^(?: {0,3}>[ \t]?)+');
final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})');
final _underline = RegExp(r'^ {0,3}(=+|-+)[ \t]*$');
