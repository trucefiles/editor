/// Commands on list items as a whole: their boxes, adding, moving and
/// removing them.
library;

import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../doc/normalized.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';

/// The box of a new item next to [item], made from its row of [leaf]:
/// none if it has none; checked in a Done section, else open.
bool? newBox(ViewRows view, ItemNode item, NodeId leaf) =>
    item.hasBox ? view.row(leaf)!.done : null;

/// [view]'s tree with [block] right after the block [leaf]; in an item,
/// as a new item of its own right after that item, with the box Enter
/// would give it.
DocTree withBlockAfter(
  ViewRows view,
  NodeId leaf,
  DocBlock block,
  FreshIds fresh,
) {
  final doc = view.doc;
  final (anchor, added) = switch (doc
      .pathOf(leaf)
      .whereType<ItemNode>()
      .lastOrNull) {
    final item? => (
      item as DocBlock,
      ItemNode(fresh.take(), [block], checked: newBox(view, item, leaf)),
    ),
    null => (doc.nodeOf(leaf)!, block),
  };
  return doc.edited({
    anchor.id: [anchor, added],
  }, fresh: fresh);
}

/// Whether [leaf] is [item]'s own line: its first block, with nothing
/// after it but its subitems.
bool isOwnLine(ItemNode item, NodeId leaf) => switch (item.children) {
  [final first, ...final rest] =>
    first.id == leaf && (rest.isEmpty || rest.first is ListNode),
  _ => false,
};

/// [item]'s box checked or unchecked; no caret after it, as after the
/// other commands on items as a whole (controls and menus send them).
Change toggle(ViewRows view, ItemNode item) => (
  doc: view.doc.withNode(item.withBox(!(item.checked ?? false))),
  caret: const NoCaret(),
);

/// [item] gone with its subitems; the caret at the start of the next
/// text shown, else at the end of the one above.
Change deleteItem(ViewRows view, ItemNode item) => (
  doc: view.doc.edited({item.id: const []}),
  caret: caretOnceGone(view, {item.id}),
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
    caret: CaretAt(TextSelection.caret(Place(text.id, 0))),
  );
}

/// [item] with its subitems moved right before [target], or after it if
/// [below], in [target]'s list, taking that list's kind; no caret after
/// it (see [toggle]).
Change moveItem(
  ViewRows view,
  ItemNode item,
  ItemNode target, {
  required bool below,
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
    caret: const NoCaret(),
  );
}

/// The checked items at the top level of [doc]'s lists (or only of
/// [list]): those the Done sections show, and the checked-items actions
/// act on.
List<ItemNode> checkedItems(DocTree doc, {ListNode? list}) => [
  for (final top in list == null ? _topLists(doc.root) : [list])
    ...top.items.where((item) => item.checked ?? false),
];

/// [items] gone with their subitems: "Clear checked items". A list they
/// would leave empty keeps one empty open item in their place, so it
/// stays to be filled again (e.g. a shopping list). No caret after it
/// (see [toggle]).
Change clearItems(ViewRows view, List<ItemNode> items) {
  final going = {for (final item in items) item.id};
  final keeping = {
    for (final item in items)
      if (view.doc.parentOf(item.id) case final ListNode list
          when list.items.every((each) => going.contains(each.id)))
        list.items.first.id,
  };
  final fresh = view.doc.freshIds;
  return (
    doc: view.doc.edited({
      for (final item in items)
        item.id: keeping.contains(item.id)
            ? [
                ItemNode(fresh.take(), [emptyParagraph(fresh)], checked: false),
              ]
            : const [],
    }, fresh: fresh),
    caret: const NoCaret(),
  );
}

/// [items] moved, with their subitems, to the end of their lists in
/// their order: "Move checked items to end", and a checked item's wait
/// ending; no caret after it (see [toggle]).
Change moveToEnd(ViewRows view, List<ItemNode> items) {
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
    caret: const NoCaret(),
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
