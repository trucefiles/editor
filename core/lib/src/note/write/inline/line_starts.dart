/// Where text lines need a backslash so that they read as text: at line
/// starts that would start a block, at a heading's end that would read
/// as its closing marks.
library;

import '../../read/syntax/block_starts.dart';
import '../../read/syntax/characters.dart';
import '../../read/syntax/link_syntax.dart';

/// The offset in [line], a line of a paragraph's text, of the character
/// to escape so it does not start a block; `null` if it starts none.
/// A [first] line must start no block at all; a later one only none that
/// ends the paragraph: what interrupts a paragraph, a setext underline,
/// a table's delimiter row.
int? lineStartEscapeAt(String line, {required bool first}) {
  final indent = line.length - line.trimLeft().length;
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
  if (!first &&
      (startsWith(setextUnderline) || tableDelimiterRow.hasMatch(rest))) {
    return indent;
  }
  if (first && rest.startsWith('[') && readLinkDefinition(rest, 0) != null) {
    return indent;
  }
  return null;
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
