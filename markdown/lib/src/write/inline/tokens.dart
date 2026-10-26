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

  /// Whether it is part of a bare link's text, which is never escaped.
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
/// untouched characters, all else fixed. A bare link's text stays as
/// written.
Iterable<Token> tokensOf(Inline inline, {bool inAutolink = false}) =>
    switch (inline) {
      TextInline(isPlain: true, :final literal) => [
        for (final char in literal.split(''))
          CharToken(char, changed: false, inAutolink: inAutolink),
      ],
      LinkInline(
        style: LinkStyle.extendedAutolink,
        :final open,
        :final children,
        :final close,
      ) =>
        [
          FixedToken(open),
          ...children.expand((child) => tokensOf(child, inAutolink: true)),
          FixedToken(close),
        ],
      ImageInline() => [FixedToken(inline.source)],
      ContainerInline(:final open, :final children, :final close) => [
        FixedToken(open),
        ...children.expand((child) => tokensOf(child, inAutolink: inAutolink)),
        FixedToken(close),
      ],
      _ => [FixedToken(inline.source)],
    };

/// What [tokens] write.
String sourceOf(Iterable<Token> tokens) =>
    tokens.map((token) => token.source).join();
