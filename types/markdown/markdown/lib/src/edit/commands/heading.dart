import '../../doc/doc_nodes.dart';
import '../../view/rows.dart';
import '../../visible/visible_text.dart';
import '../change.dart';
import '../selection.dart';

/// The level the heading button gives text of [level] (`null` for a
/// paragraph): none, 1, 2, 3, then none again; levels 4 to 6 go to none.
int? nextHeadingLevel(int? level) => switch (level) {
  null => 1,
  1 => 2,
  2 => 3,
  _ => null,
};

/// The text at [at] made a heading of [level], or a paragraph if `null`;
/// a heading holds one line, so its line breaks become spaces. Code
/// stays code. The caret stays.
Change setHeading(ViewRows view, Place at, int? level) => (
  doc: switch ((view.doc.nodeOf(at.leaf), level)) {
    (final TextNode leaf, null) => view.doc.withNode(
      ParagraphNode(leaf.id, leaf.text, source: leaf.source),
    ),
    (final TextNode leaf, final level?) => view.doc.withNode(
      HeadingNode(
        leaf.id,
        _inOneLine(leaf.text),
        level: level,
        source: leaf.source,
      ),
    ),
    _ => view.doc,
  },
  selection: TextSelection.caret(at),
);

/// [text] with its line breaks as spaces.
VisibleText _inOneLine(VisibleText text) => VisibleText([
  for (final piece in text.pieces)
    switch (piece) {
      SoftBreakPiece() || HardBreakPiece() => TextPiece(' ', piece.formatting),
      _ => piece,
    },
]);
