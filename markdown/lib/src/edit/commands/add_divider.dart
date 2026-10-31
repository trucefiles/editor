import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';
import 'items.dart';

/// A divider at the block [leaf], as one character typed there: an empty
/// paragraph becomes the divider; after any other block, in an item it
/// is a new item of its own right after it, with the box Enter would
/// give it, elsewhere it goes right after [leaf]. The caret goes to the
/// start of the text after it; after a last item, into a new empty item.
Change addDivider(ViewRows view, NodeId leaf) {
  final doc = view.doc;
  final item = doc.pathOf(leaf).whereType<ItemNode>().lastOrNull;
  return switch (doc.nodeOf(leaf)) {
    ParagraphNode(:final text) when text.isEmpty => _inPlaceOf(
      view,
      leaf,
      item,
    ),
    final block => _after(view, block!, item),
  };
}

/// The empty paragraph [leaf], in [item] if any, as a divider.
Change _inPlaceOf(ViewRows view, NodeId leaf, ItemNode? item) {
  final doc = view.doc;
  final fresh = doc.freshIds;
  final divider = DividerNode(fresh.take());
  final last = switch (item) {
    final item? => (doc.parentOf(item.id)! as ListNode).items.last == item,
    null => false,
  };
  if (!last) {
    return (
      doc: doc.edited({
        leaf: [divider],
      }, fresh: fresh),
      selection: caretAfter(view, (row) => row.leaf.id == leaf),
    );
  }
  final (next, text) = newItemAfter(view, item!, leaf, fresh);
  return (
    doc: doc.edited({
      item.id: [
        ...editedIn(item, {
          leaf: [divider],
        }),
        next,
      ],
    }, fresh: fresh),
    selection: TextSelection.caret(Place(text.id, 0)),
  );
}

/// A divider after [block], or after its [item] as an item of its own.
Change _after(ViewRows view, DocBlock block, ItemNode? item) {
  final doc = view.doc;
  final fresh = doc.freshIds;
  final divider = DividerNode(fresh.take());
  final (anchor, added) = switch (item) {
    final item? => (
      item,
      ItemNode(fresh.take(), [divider], checked: newBox(view, item, block.id)),
    ),
    null => (block, divider),
  };
  return (
    doc: doc.edited({
      anchor.id: [anchor, added],
    }, fresh: fresh),
    selection: caretAfter(view, (row) => goesWith(doc, row, {anchor.id})),
  );
}
