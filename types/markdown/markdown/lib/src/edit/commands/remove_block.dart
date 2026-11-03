import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';
import 'items.dart';
import 'line_in_place.dart';

/// [block], one without text (a divider), selected whole and gone, as
/// one selected character is. The caret goes to the end of the text
/// above if [backward], else to the start of the next text, or the other
/// way where there is none; where an empty line took its place (see
/// [_lineInItem]), into that line.
Change removeSelectedBlock(
  ViewRows view,
  NodeId block, {
  required bool backward,
}) =>
    _lineInItem(view, block) ??
    (
      doc: view.doc.edited({block: const []}),
      caret: caretOnceGone(view, {block}, above: backward),
    );

/// [block] gone by Backspace or Delete pressed right next to it, at
/// [caret], a place in a text that stays: the caret stays there.
Change removeBlockNextTo(ViewRows view, NodeId block, Place caret) =>
    (doc: _gone(view, block), caret: CaretAt(TextSelection.caret(caret)));

/// [view]'s document without [block]; see [_lineInItem].
DocTree _gone(ViewRows view, NodeId block) =>
    _lineInItem(view, block)?.doc ?? view.doc.edited({block: const []});

/// Where [block] is all its item shows as its own line, an empty line in
/// its place, so the item stays as an empty one; else `null`.
Change? _lineInItem(ViewRows view, NodeId block) => switch (view.doc.parentOf(
  block,
)) {
  final ItemNode item when isOwnLine(item, block) => lineInPlace(view, block),
  _ => null,
};
