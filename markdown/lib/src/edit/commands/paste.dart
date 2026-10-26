import '../../tree/inlines.dart';
import '../../view/rows.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../change.dart';
import '../selection.dart';
import 'over_range.dart';
import 'split_block.dart';

/// [lines] pasted over [range] (see `splitWith`); their links are new
/// links.
Edited paste(ViewRows view, TextSelection range, List<VisibleText> lines) =>
    overRange(
      view,
      range,
      (view, at) => splitWith(view, at, _withNewLinks(lines)),
    );

/// [lines] with a new mark for each link they show, written inline; a
/// bare link's text as plain text, which reads as a link again where it
/// lands as one.
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
