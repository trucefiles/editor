import 'package:collection/collection.dart';

import '../../doc/definitions.dart';
import '../../doc/doc_nodes.dart';
import '../../doc/load.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../references.dart';
import '../selection.dart';

/// A raw block (a table, HTML, link definitions or front matter) closed
/// with [raw] typed in it: what [raw] reads as (any blocks, or none)
/// takes its place; a changed raw text that changes the link definitions
/// leads reference links where they now say. [selection] stays where
/// its text stays.
Change closeRaw(ViewRows view, NodeId block, String raw, Selection selection) {
  final doc = view.doc;
  if ((doc.nodeOf(block)! as RawLeaf).raw == raw) {
    return (doc: doc, selection: selection);
  }
  final fresh = doc.freshIds;
  final read = doc.edited({block: newBlocksOf(raw, fresh)}, fresh: fresh);
  final definitions = definitionsOf(read.root);
  final changed = !const MapEquality<Object?, Object?>().equals(
    definitionsOf(doc.root),
    definitions,
  );
  return (
    doc: changed ? withResolvedReferences(read, definitions) : read,
    selection: selectionOnceGone(view, selection, {block}),
  );
}
