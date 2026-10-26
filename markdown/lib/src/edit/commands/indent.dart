/// Tab and Shift+Tab in an item: one level in or out.
library;

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';
import 'lifted_items.dart';
import 'remove_frame.dart';

/// The item whose text [leaf] is, outside a Done section: what indent
/// and outdent act on; `null` if there is none.
ItemNode? itemAt(ViewRows view, NodeId leaf) {
  if (view.row(leaf)?.done ?? true) return null;
  return switch (view.doc.parentOf(leaf)) {
    final ItemNode item => item,
    _ => null,
  };
}

/// Whether the item at [leaf] can be indented: it has an item above it
/// in its list.
bool canIndent(ViewRows view, NodeId leaf) => switch (itemAt(view, leaf)) {
  final item? =>
    (view.doc.parentOf(item.id)! as ListNode).items.first.id != item.id,
  null => false,
};

/// Whether the item at [leaf] can be outdented: it is in an item.
bool canOutdent(ViewRows view, NodeId leaf) => itemAt(view, leaf) != null;

/// The item at [selection]'s caret made the last child of the item above
/// it, its own children coming along; it joins that item's sublist if it
/// ends with one, else starts one of its list's kind.
Change indent(ViewRows view, TextSelection selection) {
  final doc = view.doc;
  final item = itemAt(view, selection.extent.leaf)!;
  final list = doc.parentOf(item.id)! as ListNode;
  final above = list.items[list.items.indexOf(item) - 1];
  final fresh = doc.freshIds;
  final into = above.withChildren(switch (above.children.last) {
    final ListNode sublist => [
      ...above.children.take(above.children.length - 1),
      sublist.withChildren([...sublist.items, item]),
    ],
    _ => [
      ...above.children,
      ListNode(fresh.take(), [item], kind: list.kind),
    ],
  });
  return (
    doc: doc.edited({
      list.id: [
        list.withChildren([
          for (final other in list.items)
            if (other == above) into else if (other != item) other,
        ]),
      ],
    }, fresh: fresh),
    selection: selection,
  );
}

/// The item at [selection]'s caret one level out, right after the item
/// it is in, the items after it in its list becoming its subitems; at a
/// list's top level, its blocks out of the list, which splits around it
/// (an empty item leaves the list, see [leaveList]).
Change outdent(ViewRows view, TextSelection selection) {
  final doc = view.doc;
  final item = itemAt(view, selection.extent.leaf)!;
  final list = doc.parentOf(item.id)! as ListNode;
  final fresh = doc.freshIds;
  final parent = doc.parentOf(list.id);
  if (parent is! ItemNode) {
    if (isEmptyItem(item)) return leaveList(view, item);
    return (
      doc: doc.edited({
        list.id: liftedOut(list, {item.id}, fresh),
      }, fresh: fresh),
      selection: selection,
    );
  }
  final index = list.items.indexOf(item);
  final following = list.items.skip(index + 1).toList();
  final children = switch ((item.children.last, following)) {
    (_, []) => item.children,
    (final ListNode sublist, _) when sublist.kind == list.kind => [
      ...item.children.take(item.children.length - 1),
      sublist.withChildren([...sublist.items, ...following]),
    ],
    _ => [
      ...item.children,
      ListNode(
        fresh.take(),
        following,
        kind: list.kind,
        numbering: list.numbering,
        source: list.source,
      ),
    ],
  };
  final staying = list.items.take(index).toList();
  final outer = editedIn(parent, {
    list.id: [if (staying.isNotEmpty) list.withChildren(staying)],
  }).single;
  return (
    doc: doc.edited({
      parent.id: [outer, item.withChildren(children)],
    }, fresh: fresh),
    selection: selection,
  );
}

/// Whether [item] shows no text and holds nothing else: only an empty
/// paragraph.
bool isEmptyItem(ItemNode item) => switch (item.children) {
  [ParagraphNode(:final text)] => text.isEmpty,
  _ => false,
};
