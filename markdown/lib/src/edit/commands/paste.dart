import '../../tree/inlines.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import 'over_range.dart';
import 'split_block.dart';
import 'text_commands.dart';

/// [lines] pasted over [range], each after an Enter in the place the
/// text has reached (new items in an item, paragraphs elsewhere, lines
/// in code); the caret after them. Their links are new links.
Edited paste(
  ShownDocument document,
  TextSelection range,
  List<VisibleText> lines,
) => _withNewLinks(lines).indexed.fold(cleared(document, range), (
  edited,
  entry,
) {
  final (index, line) = entry;
  final split = index == 0 ? edited : atCaret(edited, splitBlock);
  return line.isEmpty
      ? split
      : atCaret(split, (document, at) => typed(document, at, at.offset, line));
});

/// [lines] with a new mark for each link they show, written inline; a
/// bare link's text as plain text, which reads as a link again where
/// it lands as one.
List<VisibleText> _withNewLinks(List<VisibleText> lines) {
  final marks = lines
      .expand((line) => line.pieces)
      .map((piece) => piece.formatting.link)
      .nonNulls
      .toSet();
  final fresh = {
    for (final mark in marks)
      mark: mark.style == LinkStyle.extendedAutolink
          ? null
          : LinkMark(
              destination: mark.destination,
              title: mark.title,
              style: LinkStyle.inline,
            ),
  };
  return [
    for (final line in lines)
      VisibleText([
        for (final piece in line.pieces)
          switch (piece.formatting.link) {
            null => piece,
            final mark => piece.withFormatting(
              piece.formatting.withLink(fresh[mark]),
            ),
          },
      ]),
  ];
}
