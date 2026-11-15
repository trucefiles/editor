import '../../doc/doc_nodes.dart';
import '../../view/rows.dart';
import '../change.dart';
import 'items.dart';
import 'line_in_place.dart';

/// [block], one without text (a divider), selected whole and gone, as
/// one selected character is, the caret staying on the side the key
/// came from: at the start of the next text if [backward] (Backspace
/// from below), else at the end of the text above, or the other way
/// where there is none; where an empty line took its place (see
/// [_lineInItem]), into that line.
Change removeSelectedBlock(
  ViewRows view,
  NodeId block, {
  required bool backward,
}) =>
    _lineInItem(view, block) ??
    (
      doc: view.doc.edited({block: const []}),
      caret: caretOnceGone(view, {block}, above: !backward),
    );

/// Where [block] is all its item shows as its own line, an empty line in
/// its place, so the item stays as an empty one; else `null`.
Change? _lineInItem(ViewRows view, NodeId block) => switch (view.doc.parentOf(
  block,
)) {
  final ItemNode item when isOwnLine(item, block) => lineInPlace(view, block),
  _ => null,
};
