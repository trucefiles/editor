/// Where text lines need a backslash so that they read as text: at line
/// starts that would start a block, at a heading's end that would read
/// as its closing marks.
library;

import '../../read/syntax/block_starts.dart';
import '../../read/syntax/characters.dart';
import '../../read/syntax/link_syntax.dart';
import '../../read/syntax/table_rows.dart';

/// The offset in [line], a line of a paragraph's text, of the character
/// to escape so it does not start a block; `null` if it starts none.
/// A [first] line must start no block at all (nor a link definition
/// with the lines [after] it), nor a thematic break with the [bullet]
/// marker right before it, if any; a later one only none
/// that ends the paragraph: what interrupts a paragraph, and unless
/// [lazy] a setext underline or a table's delimiter row (under
/// [previous], the line before, if known).
int? lineStartEscapeAt(
  String line, {
  required bool first,
  bool lazy = false,
  String? previous,
  String? bullet,
  String after = '',
}) =>
    _blockStartAt(line, first: first, after: after) ??
    (first && bullet != null && _breaksWith(bullet, line)
        ? _indentOf(line)
        : null) ??
    (!first && !lazy && _takenByParagraph(line, previous: previous)
        ? _indentOf(line)
        : null);

/// Whether [line] after a [bullet] marker reads as a thematic break.
bool _breaksWith(String bullet, String line) =>
    thematicBreak.matchAsPrefix('$bullet ${line.trimLeft()}') != null;

int _indentOf(String line) => line.length - line.trimLeft().length;

/// The offset in [line] of the start of a block it starts, for a [first]
/// line any block (with the lines [after] it), else one that interrupts
/// a paragraph; `null` if none.
int? _blockStartAt(String line, {required bool first, String after = ''}) {
  final indent = _indentOf(line);
  if (indent > 3) return null;
  final rest = line.substring(indent);
  if (rest.isEmpty) return null;
  bool startsWith(RegExp pattern) => pattern.matchAsPrefix(rest) != null;
  bool contentAfter(int end) => !isBlankText(rest.substring(end));
  if (startsWith(atxHeading) ||
      rest.startsWith('>') ||
      startsWith(codeFence) ||
      startsWith(thematicBreak) ||
      htmlBlockStarts.entries.any(
        (start) => (first || start.key < 7) && startsWith(start.value),
      )) {
    return indent;
  }
  if (bulletMarker.matchAsPrefix(rest) case final marker?
      when first || contentAfter(marker.end)) {
    return indent;
  }
  if (numberedMarker.matchAsPrefix(rest) case final marker?
      when first || (int.parse(marker[1]!) == 1 && contentAfter(marker.end))) {
    return indent + marker[1]!.length;
  }
  if (first &&
      rest.startsWith('[') &&
      readLinkDefinition('$rest$after', 0) != null) {
    return indent;
  }
  return null;
}

/// Whether [line], right after a paragraph's last line, ends the
/// paragraph by starting a block, rather than going on in it (as text,
/// a setext underline or a table's delimiter row).
bool endsParagraph(String line) =>
    endsLazyParagraph(line) && !_takenByParagraph(line);

/// Whether [line], right after a paragraph's last line but outside the
/// paragraph's containers, ends the paragraph by starting a block that
/// interrupts it, rather than going on in it as a lazy line.
bool endsLazyParagraph(String line) =>
    !isBlankText(line) && _blockStartAt(line, first: false) != null;

/// Whether [line] goes on in a paragraph as its setext underline or a
/// table's delimiter row: under [previous] if known, else under any line.
bool _takenByParagraph(String line, {String? previous}) {
  if (_indentOf(line) > 3) return false;
  final rest = line.trimLeft();
  return setextUnderline.matchAsPrefix(rest) != null ||
      switch (previous) {
        final header? => startsTable(header.trimLeft(), rest),
        null => tableDelimiterRow.hasMatch(rest),
      };
}

/// The offset in [text], an ATX heading's text, of the `#` to escape so
/// that its end is not read as the heading's closing marks; `null` if
/// it needs none.
int? headingEndEscapeAt(String text) =>
    switch (_closingMarks.firstMatch(text)) {
      final match? => match.end - match[1]!.length,
      null => null,
    };

final _closingMarks = RegExp(r'(?:^|[ \t])(#+)$');
