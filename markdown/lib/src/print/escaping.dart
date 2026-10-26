/// The printer's escaping rules: fixed rules on what a character is and
/// what prints next to it, so that text reads back as the text it is.
/// The one owner of these rules.
library;

import 'char_classes.dart';

/// Where a character of text prints, as escaping needs to know.
typedef CharPlace = ({
  /// The last character printed before it; `null` at the text's start.
  String? before,

  /// The first character printed after it; `null` at the text's end.
  String? after,

  /// The text characters right after it, up to the next non-text.
  String rest,

  /// Whether it is in a link's text.
  bool inLink,

  /// Whether a `]` prints somewhere after it.
  bool bracketAfter,

  /// Whether it is in text that would read as a bare link, which it
  /// isn't.
  bool inBareLinkShape,
});

/// How [char] prints at [place]: as is, after a backslash, or as a
/// character reference.
///
/// Escaped always: `\`, `*`, `` ` ``, `~`. Where they would read as
/// marks: `_` at a word's edge, `<` before a letter, `/`, `!` or `?`,
/// `[` before a `]`, `!` before a link's `[`, `&` that would read as a
/// reference, `]` in a link's text, and the `.` and `:` of text shaped
/// like a bare link. A space or tab at the text's start, and invisible
/// characters, print as references. Line starts are [lineStartEscaped]'s.
String escapedChar(String char, CharPlace place) => switch (char) {
  _ when printsAsReference(char, first: place.before == null) => referenceOf(
    char,
  ),
  r'\' || '*' || '`' || '~' => '\\$char',
  '_' when !_inWord(place.before) || !_inWord(place.after) => r'\_',
  '<' when _opensTag.hasMatch(place.after ?? '') => r'\<',
  '[' when place.inLink || place.bracketAfter => r'\[',
  ']' when place.inLink => r'\]',
  '!' when place.after == '[' => r'\!',
  '&' when _reference.hasMatch(place.rest) => r'\&',
  '.' || ':' when place.inBareLinkShape => '\\$char',
  _ => char,
};

/// Whether [char] prints as a reference, [first] in the text: invisible,
/// or a space or tab at the start.
bool printsAsReference(String char, {required bool first}) =>
    isInvisible(char) || (first && (char == ' ' || char == '\t'));

/// The reference [char] prints as where it would be lost: a space or tab
/// at a line's start.
String referenceOf(String char) => switch (char) {
  ' ' => '&#32;',
  '\t' => '&#9;',
  ' ' => '&nbsp;',
  _ => '&#${char.runes.single};',
};

bool _inWord(String? char) => char != null && classOf(char) == CharClass.other;

final _opensTag = RegExp(r'^[A-Za-z/!?]');

/// What follows an `&` that reads as a character reference.
final _reference = RegExp(
  r'^(?:#[xX][0-9a-fA-F]{1,6}|#[0-9]{1,7}|[A-Za-z][A-Za-z0-9]{1,31});',
);

/// [line], a printed line of a paragraph's text after its containers'
/// marks, with the escape that keeps it from starting a block: before a
/// `#`, `>`, `-`, `+`, `=`, `|` or `:` at its start, and before the `.`
/// or `)` after a run of digits there.
String lineStartEscaped(String line) => switch (_lineStart.firstMatch(line)) {
  final match? when match[1] != null => '\\$line',
  final match? => '${match[2]}\\${line.substring(match[2]!.length)}',
  null => line,
};

final _lineStart = RegExp(r'^(?:([#>\-+=|:])|(\d+)[.)])');

/// [content], an ATX heading's printed text, with the `#` escaped that
/// would read as closing marks.
String headingEndEscaped(String content) =>
    switch (_closingMarks.firstMatch(content)) {
      final match? =>
        '${content.substring(0, match.end - match[1]!.length)}\\'
            '${match[1]}',
      null => content,
    };

final _closingMarks = RegExp(r'(?:^|[ \t])(#+)$');

/// [info], a code block's info string, as written after its fence: its
/// backslashes before punctuation and `&`s that read as references
/// escaped.
String infoEscaped(String info) =>
    info.replaceAllMapped(_infoEscapes, (match) => '\\${match[0]}');

final _infoEscapes = RegExp(
  r'''\\(?=[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~])|&(?=#?[A-Za-z0-9]+;)''',
);
