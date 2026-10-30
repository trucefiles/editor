import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../view/rows.dart';
import '../change.dart';
import 'items.dart';

/// A divider after the block [leaf]: in an item, as a new item of its own
/// right after it, with the box Enter would give it; elsewhere right
/// after [leaf]. The caret goes to the start of the text after it.
Change addDivider(ViewRows view, NodeId leaf) {
  final doc = view.doc;
  final fresh = doc.freshIds;
  final divider = DividerNode(fresh.take());
  final (anchor, added) = switch (doc
      .pathOf(leaf)
      .whereType<ItemNode>()
      .lastOrNull) {
    final item? => (
      item,
      ItemNode(fresh.take(), [divider], checked: newBox(view, item, leaf)),
    ),
    null => (doc.nodeOf(leaf)!, divider),
  };
  return (
    doc: doc.edited({
      anchor.id: [anchor, added],
    }, fresh: fresh),
    selection: caretAfter(view, (row) => goesWith(doc, row, {anchor.id})),
  );
}
