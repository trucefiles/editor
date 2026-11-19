import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../print/links.dart';
import '../../tree/inlines.dart';
import '../../view/rows.dart';
import '../../visible/visible_text.dart';
import '../change.dart';
import '../selection.dart';
import 'items.dart';
import 'line_after.dart';

/// A divider at the block [leaf] (see [addBlock]).
Change addDivider(ViewRows view, NodeId leaf) =>
    addBlock(view, leaf, (fresh) => DividerNode(fresh.take()));

/// An image leading to [link], with no description, on a line of its own
/// at the block [leaf] (see [addBlock]).
Change addImage(ViewRows view, NodeId leaf, String link) => addBlock(
  view,
  leaf,
  (fresh) => ParagraphNode(
    fresh.take(),
    VisibleText([
      ObjectPiece(
        ImageInline(
          '![',
          const [],
          '](${destinationSource(link)})',
          destination: link,
        ),
      ),
    ]),
  ),
);

/// The block [make] gives at the block [leaf], as one character typed
/// there: an empty paragraph becomes it; after any other block, in an
/// item it is a new item of its own right after it, with the box Enter
/// would give it, elsewhere it goes right after [leaf]. The caret goes
/// to the start of the text after it; where no item of its list shows
/// next in its section, into a new empty item after it.
Change addBlock(
  ViewRows view,
  NodeId leaf,
  DocBlock Function(FreshIds fresh) make,
) {
  final doc = view.doc;
  final fresh = doc.freshIds;
  final block = make(fresh);
  final item = doc.pathOf(leaf).whereType<ItemNode>().lastOrNull;
  return switch (doc.nodeOf(leaf)) {
    ParagraphNode(:final text) when text.isEmpty => _inPlaceOf(
      view,
      leaf,
      block,
      item,
      fresh,
    ),
    _ => (
      doc: withBlockAfter(view, leaf, block, fresh),
      caret: caretOrEnd(
        caretAfter(view, (row) => goesWith(doc, row, {item?.id ?? leaf})),
      ),
    ),
  };
}

/// [block] in place of the empty paragraph [leaf], in [item] if any.
Change _inPlaceOf(
  ViewRows view,
  NodeId leaf,
  DocBlock block,
  ItemNode? item,
  FreshIds fresh,
) {
  final doc = view.doc.edited({
    leaf: [block],
  }, fresh: fresh);
  final next = caretAfter(view, (row) => row.leaf.id == leaf);
  return item == null || _goesOnInList(view, item, leaf, next)
      ? (doc: doc, caret: caretOrEnd(next))
      : lineAfter(view.over(doc), block.id);
}

/// Whether the caret [next] goes to is in [item]'s list and in the
/// section [leaf] shows in: the list goes on there.
bool _goesOnInList(
  ViewRows view,
  ItemNode item,
  NodeId leaf,
  TextSelection? next,
) {
  final list = view.doc.parentOf(item.id)!;
  return switch (next == null ? null : view.row(next.extent.leaf)) {
    final row? =>
      row.done == view.row(leaf)!.done &&
          view.doc.pathOf(row.leaf.id).any((node) => node.id == list.id),
    null => false,
  };
}
