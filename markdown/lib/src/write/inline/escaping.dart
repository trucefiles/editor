import 'package:collection/collection.dart';

import '../../read/inline_reader.dart';
import '../../tree/blocks.dart';
import '../../tree/inlines.dart';
import '../../visible/visible_text.dart';
import 'line_starts.dart';
import 'tokens.dart';

/// Which text a leaf's inline content is, for its line starts.
enum TextLines {
  /// A paragraph's or setext heading's lines: none may start a block.
  paragraph,

  /// An ATX heading's one line: its end must not read as closing marks.
  atxHeading,
}

/// How a line of text is written after its containers' parts: its own
/// [indent], and whether it is [lazy], lacking some containers' marks,
/// where only a block that interrupts a paragraph would end it.
typedef LineLead = ({String indent, bool lazy});

const _noLead = (indent: '', lazy: false);

/// The source of [tokens] with the escapes that make it read as [text]
/// (with [definitions]), its lines written after [leads]: the one
/// escaping rule. `null` if no escapes do,
/// which only text whose spans cannot be written comes to.
///
/// A character is escaped only where it would otherwise change meaning:
/// where a line would start a block, or where the reader takes it as
/// syntax (a delimiter that pairs, a bracket that links, the start of an
/// escape or reference). Characters the edit put in are escaped first;
/// untouched ones only when that is not enough. After [_rounds] rounds,
/// every punctuation character the edit put in is escaped, then every
/// one.
String? escapedSource(
  List<Token> tokens,
  VisibleText text, {
  required TextLines lines,
  required Map<String, LinkDefinition> definitions,
  List<LineLead> leads = const [],
}) {
  bool readsRight(String source) =>
      visibleTextOf(readInlineText(source, definitions: definitions))
          .looksLike(text);

  var current = _leadingSpaceKept(
    _lineEndsAsReferences(_shortcutsKept(tokens)),
  );
  for (var round = 0; round < _rounds; round++) {
    current = _lineStartsEscaped(current, lines, leads);
    final source = sourceOf(current);
    if (readsRight(source)) return source;
    final misread = _misread(
      current,
      readInlineText(source, definitions: definitions),
    );
    final changed = {
      for (final index in misread)
        if (current[index] case CharToken(changed: true)) index,
    };
    final escape = changed.isEmpty ? misread : changed;
    if (escape.isEmpty) break;
    current = _escaped(current, escape);
  }
  for (final all in [false, true]) {
    final escaped = _lineStartsEscaped(
      _escaped(current, {
        for (final (index, token) in current.indexed)
          if (token case CharToken(escapable: true, :final changed)
              when all || changed)
            index,
      }),
      lines,
      leads,
    );
    final source = sourceOf(escaped);
    if (readsRight(source)) return source;
    current = escaped;
  }
  return null;
}

const _rounds = 3;

/// [tokens] with each shortcut reference collapsed where a bracket or
/// parenthesis follows it, which would make it another reference or an
/// inline link.
List<Token> _shortcutsKept(List<Token> tokens) => [
  for (final (index, token) in tokens.indexed)
    switch ((token, tokens.elementAtOrNull(index + 1)?.source)) {
      (ShortcutToken(:final source), final String next)
          when next.startsWith('[') || next.startsWith('(') =>
        FixedToken('$source[]'),
      (ShortcutToken(:final source), _) => FixedToken(source),
      _ => token,
    },
];

/// [tokens] with a line ending character of the text (one a character
/// reference showed) written as a character reference again, as the
/// file's line endings break lines.
List<Token> _lineEndsAsReferences(List<Token> tokens) => [
  for (final token in tokens)
    switch (token) {
      CharToken(char: '\n') => const FixedToken('&#10;'),
      CharToken(char: '\r') => const FixedToken('&#13;'),
      _ => token,
    },
];

/// [tokens] with a space or tab at a line's start, which the reader
/// would take off, written as a character reference.
List<Token> _leadingSpaceKept(List<Token> tokens) => [
  for (final (index, token) in tokens.indexed)
    switch (token) {
      CharToken(char: final char && (' ' || '\t'))
          when index == 0 || tokens[index - 1].source.endsWith('\n') =>
        FixedToken(char == ' ' ? '&#32;' : '&#9;'),
      _ => token,
    },
];

/// [tokens] with the line starts escaped that would start a block after
/// their [leads], and for a heading the end that would read as closing
/// marks.
List<Token> _lineStartsEscaped(
  List<Token> tokens,
  TextLines lines,
  List<LineLead> leads,
) {
  final starts = _startsOf(tokens);
  final source = sourceOf(tokens);
  final escapes = switch (lines) {
    TextLines.atxHeading => [?headingEndEscapeAt(source)],
    TextLines.paragraph => [
      for (final (index, lineStart) in _lineStarts(source).indexed)
        ?_lineEscapeAt(
          source,
          lineStart,
          leads.elementAtOrNull(index) ?? _noLead,
        ),
    ],
  };
  return _escaped(tokens, {
    for (final offset in escapes)
      if (_tokenAt(starts, offset) case final index?
          when tokens[index].escapable)
        index,
  });
}

/// The offset in [source] of the escape that the line at [start] needs
/// after [lead]; `null` if it needs none.
int? _lineEscapeAt(String source, int start, LineLead lead) =>
    switch (lineStartEscapeAt(
      '${lead.indent}${source.substring(start, _lineEnd(source, start))}',
      first: start == 0,
      lazy: lead.lazy,
      previous: start == 0
          ? null
          : source.substring(_lineStart(source, start - 1), start - 1),
    )) {
      final at? => start + at - lead.indent.length,
      null => null,
    };

/// Where the line holding [offset] starts in [source].
int _lineStart(String source, int offset) =>
    offset == 0 ? 0 : source.lastIndexOf('\n', offset - 1) + 1;

Iterable<int> _lineStarts(String source) => [
  0,
  for (final (index, char) in source.split('').indexed)
    if (char == '\n') index + 1,
];

int _lineEnd(String source, int start) => switch (source.indexOf('\n', start)) {
  -1 => source.length,
  final end => end,
};

/// Where each token starts in the source the tokens write.
List<int> _startsOf(List<Token> tokens) {
  var offset = 0;
  return [
    for (final token in tokens)
      (offset += token.source.length) - token.source.length,
  ];
}

/// The token that starts at [offset]; `null` if none does.
int? _tokenAt(List<int> starts, int offset) {
  final index = lowerBound(starts, offset);
  return index < starts.length && starts[index] == offset ? index : null;
}

/// The character tokens the reader took as syntax in [read]: those in no
/// text node, and those that start an escape or reference they were not
/// written as.
Set<int> _misread(List<Token> tokens, InlineText read) {
  final texts = _textRanges(read.inlines, read.before.length);
  final textStarts = [for (final range in texts) range.start];
  bool readAsText(int offset) {
    final index = lowerBound(textStarts, offset + 1) - 1;
    if (index < 0 || offset >= texts[index].end) return false;
    return texts[index].plain || texts[index].start != offset;
  }

  final starts = _startsOf(tokens);
  return {
    for (final (index, token) in tokens.indexed)
      if (token.escapable && !readAsText(starts[index])) index,
  };
}

typedef _TextRange = ({int start, int end, bool plain});

/// Where the text nodes among [inlines] are in their source, from
/// [start] on, in order.
List<_TextRange> _textRanges(List<Inline> inlines, int start) {
  final ranges = <_TextRange>[];
  var offset = start;
  void walk(List<Inline> nodes) {
    for (final node in nodes) {
      switch (node) {
        case TextInline(:final source, :final isPlain):
          ranges.add((
            start: offset,
            end: offset + source.length,
            plain: isPlain,
          ));
          offset += source.length;
        case ContainerInline(:final open, :final children, :final close):
          offset += open.length;
          walk(children);
          offset += close.length;
        case _:
          offset += node.source.length;
      }
    }
  }

  walk(inlines);
  return ranges;
}

List<Token> _escaped(List<Token> tokens, Set<int> indexes) => [
  for (final (index, token) in tokens.indexed)
    if (indexes.contains(index) && token is CharToken)
      token.asEscaped
    else
      token,
];
