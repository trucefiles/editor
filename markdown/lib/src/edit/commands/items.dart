/// Commands on list items as a whole: their boxes, adding, moving and
/// removing them.
library;

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../doc/normalized.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';

/// [item]'s box checked or unchecked; [selection] stays.
Change toggle(ViewRows view, ItemNode item, Selection selection) => (
  doc: view.doc.withNode(item.withBox(!(item.checked ?? false))),
  selection: selection,
);

/// [item] gone with its subitems; the caret at the start of the next
/// text shown, else at the end of the one above.
Change deleteItem(ViewRows view, ItemNode item) => (
  doc: view.doc.edited({item.id: const []}),
  selection: caretOnceGone(view, {item.id}),
);

/// Where the Add item button adds an item in its list.
enum AddAt {
  first,
  last,

  /// Right after the last item not checked: checked items gathered at
  /// the end stay below it.
  afterOpen,
}

/// A new empty item in [list], [at] its place: with an open box where
/// the list's items have boxes.
Change addItem(ViewRows view, ListNode list, {required AddAt at}) {
  final fresh = view.doc.freshIds;
  final text = emptyParagraph(fresh);
  final item = ItemNode(fresh.take(), [
    text,
  ], checked: list.items.any((item) => item.hasBox) ? false : null);
  final index = switch (at) {
    AddAt.first => 0,
    AddAt.last => list.items.length,
    AddAt.afterOpen =>
      list.items.lastIndexWhere((item) => !(item.checked ?? false)) + 1,
  };
  return (
    doc: view.doc.edited({
      list.id: [
        list.withChildren([
          ...list.items.take(index),
          item,
          ...list.items.skip(index),
        ]),
      ],
    }, fresh: fresh),
    selection: TextSelection.caret(Place(text.id, 0)),
  );
}

/// [item] with its subitems moved right before [target], or after it if
/// [below], in [target]'s list, taking that list's kind; [selection]
/// stays.
Change moveItem(
  ViewRows view,
  ItemNode item,
  ItemNode target, {
  required bool below,
  required Selection selection,
}) {
  final doc = view.doc;
  assert(
    !nodesIn(item).any((node) => node.id == target.id),
    'an item moves outside itself',
  );
  // The target may hold the item (a subitem moved out of it).
  final removed = {item.id: const <DocBlock>[]};
  final staying = editedIn(target, removed).single;
  return (
    doc: doc.edited({
      ...removed,
      target.id: [if (!below) item, staying, if (below) item],
    }),
    selection: selection,
  );
}

/// The checked items at the top level of [doc]'s lists (or only of
/// [list]): those the Done sections show, and the checked-items actions
/// act on.
List<ItemNode> checkedItems(DocTree doc, {ListNode? list}) => [
  for (final top in list == null ? _topLists(doc.root) : [list])
    ...top.items.where((item) => item.checked ?? false),
];

/// [items] gone with their subitems: "Clear checked items"; [selection]
/// kept if its text stays, else as for [deleteItem].
Change clearItems(ViewRows view, List<ItemNode> items, Selection selection) {
  final gone = {for (final item in items) item.id};
  return (
    doc: view.doc.edited({for (final id in gone) id: const []}),
    selection: selectionOnceGone(view, selection, gone),
  );
}

/// [items] moved, with their subitems, to the end of their lists in
/// their order: "Move checked items to end", and a checked item's wait
/// ending; [selection] stays.
Change moveToEnd(ViewRows view, List<ItemNode> items, Selection selection) {
  final moving = {for (final item in items) item.id};
  final lists = {for (final item in items) view.doc.parentOf(item.id)!.id};
  // One list at a time: one may hold another.
  return (
    doc: lists.fold(view.doc, (doc, id) {
      final list = doc.nodeOf(id)! as ListNode;
      return doc.withNode(
        list.withChildren([
          for (final item in list.items)
            if (!moving.contains(item.id)) item,
          for (final item in list.items)
            if (moving.contains(item.id)) item,
        ]),
      );
    }),
    selection: selection,
  );
}

/// The lists in [container] that are in no item.
Iterable<ListNode> _topLists(DocContainer container) =>
    container.children.expand(
      (child) => switch (child) {
        final ListNode list => [list],
        final QuoteNode quote => _topLists(quote),
        _ => const <ListNode>[],
      },
    );
