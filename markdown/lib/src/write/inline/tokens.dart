import '../../read/syntax/characters.dart';
import '../../tree/inlines.dart';

/// One piece of inline source a writer puts out. Text is split into
/// [CharToken]s so that escaping can add a backslash to one character;
/// everything else is a [FixedToken], written as it is.
sealed class Token {
  const Token();

  /// What it writes.
  String get source;

  /// Whether a backslash can escape it.
  bool get escapable => false;
}

/// Source written as it is: marks, breaks, code spans, raw HTML, images,
/// and characters already escaped or written as references.
final class FixedToken extends Token {
  const FixedToken(this.source);

  @override
  final String source;

  @override
  String toString() => 'Fixed($source)';
}

/// A shortcut reference (`![a]`) written as it is, unless a bracket or
/// parenthesis follows: then collapsed (`![a][]`), so that it stays
/// itself.
final class ShortcutToken extends Token {
  const ShortcutToken(this.source);

  @override
  final String source;

  @override
  String toString() => 'Shortcut($source)';
}

/// A character the old text spelled for its line start, as an escape
/// (`\#`, `1\.`) or a reference (`&#32;`): written so only while it is
/// at a line start (see [isLineStartSpot]); elsewhere as the plain
/// character, escaped only where it must be.
final class LineStartToken extends Token {
  const LineStartToken(this.source, this.char);

  @override
  final String source;

  final String char;

  @override
  String toString() => 'LineStart($source)';
}

/// One literal character of text, written as itself unless [escaped].
final class CharToken extends Token {
  const CharToken(
    this.char, {
    required this.changed,
    this.escaped = false,
    this.inAutolink = false,
  });

  final String char;

  /// Whether the edit put it here; untouched characters are escaped only
  /// when nothing else can fix a reading.
  final bool changed;

  final bool escaped;

  /// Whether it is part of an autolink's text, which is never escaped.
  final bool inAutolink;

  @override
  bool get escapable => !inAutolink && !escaped && isAsciiPunctuation(char);

  @override
  String get source => escaped ? '\\$char' : char;

  CharToken get asEscaped =>
      CharToken(char, changed: changed, escaped: true, inAutolink: inAutolink);

  @override
  String toString() => 'Char(${escaped ? r'\' : ''}$char)';
}

/// The tokens that write [inline] as it was read: plain text as
/// untouched characters, the [lineStarts] spellings as [LineStartToken]s,
/// all else fixed. An autolink's text stays as written.
Iterable<Token> tokensOf(
  Inline inline, {
  Set<Inline> lineStarts = const {},
  bool inAutolink = false,
}) => switch (inline) {
  TextInline(isPlain: true, :final literal) => [
    for (final char in literal.split(''))
      CharToken(char, changed: false, inAutolink: inAutolink),
  ],
  TextInline(:final source, :final literal) when lineStarts.contains(inline) =>
    [LineStartToken(source, literal)],
  LinkInline(
    style: LinkStyle.extendedAutolink || LinkStyle.autolink,
    :final open,
    :final children,
    :final close,
  ) =>
    [
      FixedToken(open),
      ...children.expand(
        (child) => tokensOf(child, lineStarts: lineStarts, inAutolink: true),
      ),
      FixedToken(close),
    ],
  ImageInline() => [FixedToken(inline.source)],
  ContainerInline(:final open, :final children, :final close) => [
    FixedToken(open),
    ...children.expand(
      (child) =>
          tokensOf(child, lineStarts: lineStarts, inAutolink: inAutolink),
    ),
    FixedToken(close),
  ],
  _ => [FixedToken(inline.source)],
};

/// Whether a character after [line], the part of its line before it,
/// is where a line start escapes: the line's start, or after an ordered
/// list marker's digits.
bool isLineStartSpot(String line) => _digits.hasMatch(line);

final _digits = RegExp(r'^[0-9]*$');

/// The text nodes of [inlines] that spell one character for its line
/// start the way the writer does (an escape, or a space's or tab's
/// reference) and stand at a line start (see [isLineStartSpot]).
Set<Inline> lineStartSpellings(List<Inline> inlines) {
  final found = Set<Inline>.identity();
  var line = '';
  void wrote(String source) => line = (line + source).split('\n').last;

  void walk(List<Inline> nodes) {
    for (final node in nodes) {
      switch (node) {
        case TextInline(:final source)
            when isLineStartSpot(line) && _spellsLineStart(node):
          found.add(node);
          wrote(source);
        case ContainerInline(:final open, :final children, :final close)
            when node is! ImageInline:
          wrote(open);
          walk(children);
          wrote(close);
        case _:
          wrote(node.source);
      }
    }
  }

  walk(inlines);
  return found;
}

bool _spellsLineStart(TextInline text) => switch (text) {
  TextInline(isPlain: false, :final literal, :final source)
      when literal.length == 1 =>
    source == '\\$literal' || source == '&#32;' || source == '&#9;',
  _ => false,
};

/// What [tokens] write.
String sourceOf(Iterable<Token> tokens) =>
    tokens.map((token) => token.source).join();
