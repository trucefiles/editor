import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../view/rows.dart';
import '../../visible/visible_text.dart';
import '../change.dart';
import '../selection.dart';
import '../text_places.dart';
import 'items.dart';
import 'text_commands.dart';

/// Enter at [at]: the text place split there (see [splitWith]).
Change splitBlock(ViewRows view, Place at) =>
    splitWith(view, at, [VisibleText.empty, VisibleText.empty]);

/// [lines] typed at [at] with an Enter between each two, as a paste
/// does: in code, line breaks. In other text, the text place splits
/// into one part per line: the first holds the text before the caret
/// and the first line, the last holds the last line and the text after
/// the caret (without the spaces it starts with, see [newLineStart]).
/// In an item each part is an item (the last with what followed the
/// text in the item), elsewhere each new part is a paragraph. The text
/// place itself stays the first part, or the last where it splits at
/// its very start before an empty first line (for an item, its first
/// text; elsewhere, text that is not empty): the parts above it are new.
/// The caret goes after the last line.
Change splitWith(ViewRows view, Place at, List<VisibleText> lines) {
  final doc = view.doc;
  final leaf = doc.nodeOf(at.leaf)! as DocLeaf;
  if (leaf is! TextNode) {
    return typed(view, at, at.offset, _joinedLines(lines));
  }
  if (lines.length < 2) return typed(view, at, at.offset, lines.single);
  final fresh = doc.freshIds;
  final parent = doc.parentOf(leaf.id)!;
  final keptLast =
      at.offset == 0 &&
      lines.first.isEmpty &&
      switch (parent) {
        ItemNode(:final children) => children.first == leaf,
        _ => !leaf.text.isEmpty,
      };
  final kept = keptLast ? lines.length - 1 : 0;
  final leaves = [
    for (final (index, line) in lines.indexed)
      withLeafText(
        index == kept ? leaf : ParagraphNode(fresh.take(), VisibleText.empty),
        _joined([
          if (index == 0) leaf.text.slice(0, at.offset),
          line,
          if (index == lines.length - 1) _after(leaf, at, keptLast),
        ]),
      ),
  ];
  return (
    doc: switch (parent) {
      final ItemNode item => _splitItem(
        view,
        item,
        leaf,
        leaves,
        at,
        fresh,
        kept,
      ),
      _ => doc.edited({leaf.id: leaves}, fresh: fresh),
    },
    selection: TextSelection.caret(Place(leaves.last.id, lines.last.length)),
  );
}

/// [leaf]'s text after [at] for the last part: as it is where [leaf]
/// stays the last part, else without the spaces it starts with.
VisibleText _after(TextNode leaf, Place at, bool keptLast) => keptLast
    ? leaf.text
    : leaf.text.slice(newLineStart(leaf.text, at.offset), leaf.text.length);

/// [item] split into one item per leaf of [leaves], the parts of [leaf]:
/// the first item with what came before [leaf], the last with what came
/// after it (its subitems); [item] itself is item [kept]. Split at its
/// text's end, what came after stays with [item]: a new empty item never
/// takes another's subitems.
DocTree _splitItem(
  ViewRows view,
  ItemNode item,
  TextNode leaf,
  List<DocLeaf> leaves,
  Place at,
  FreshIds fresh,
  int kept,
) {
  final index = item.children.indexOf(leaf);
  final box = newBox(view, item, at);
  final rest = kept == 0 && textOf(leaves.last).isEmpty ? 0 : leaves.length - 1;
  final items = [
    for (final (part, text) in leaves.indexed)
      [
        if (part == 0) ...item.children.take(index),
        text,
        if (part == rest) ...item.children.skip(index + 1),
      ],
  ];
  return view.doc.edited({
    item.id: [
      for (final (part, children) in items.indexed)
        part == kept
            ? item.withChildren(children)
            : ItemNode(fresh.take(), children, checked: box),
    ],
  }, fresh: fresh);
}

/// [lines] as one text, a line break between each two.
VisibleText _joinedLines(List<VisibleText> lines) => _joined([
  for (final (index, line) in lines.indexed) ...[
    if (index > 0) VisibleText([TextPiece('\n')]),
    line,
  ],
]);

/// [texts] one after another.
VisibleText _joined(List<VisibleText> texts) =>
    VisibleText([for (final text in texts) ...text.pieces]);
