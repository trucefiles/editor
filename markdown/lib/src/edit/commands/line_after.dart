import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../doc/normalized.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';
import 'items.dart';

/// Enter on [block], selected whole (a divider): an empty line right
/// after it, as after one character; in an item, a new item after it,
/// with the box Enter would give it. The caret goes into the new line.
Change lineAfter(ViewRows view, NodeId block) {
  final doc = view.doc;
  final fresh = doc.freshIds;
  final item = doc.pathOf(block).whereType<ItemNode>().lastOrNull;
  final next = item == null ? null : newItemAfter(view, item, block, fresh);
  final text = next?.$2 ?? emptyParagraph(fresh);
  final DocBlock anchor = item ?? doc.nodeOf(block)!;
  final DocBlock added = next?.$1 ?? text;
  return (
    doc: doc.edited({
      anchor.id: [anchor, added],
    }, fresh: fresh),
    selection: TextSelection.caret(Place(text.id, 0)),
  );
}
