import '../../tree/blocks.dart';
import '../../write/draft.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import '../shown/slot.dart';
import 'outline.dart';

/// [item]'s box checked or unchecked; the selection stays.
Edit toggle(ShownDocument document, ItemBlock item, Selection selection) =>
    Edit(
      replaced: {
        item.id: [
          ItemDraft.of(
            item,
            kept(item.children),
            checked: !(item.checked ?? false),
          ),
        ],
      },
      selection: selection,
    );

/// [item] gone with its subitems; the caret at the start of the next
/// text shown, else at the end of the one above.
Edit deleteItem(ShownDocument document, ItemBlock item) {
  final list = document.tree.parentOf(item)! as ListBlock;
  return Edit(
    replaced: {list.id: listWith(list, itemsWithout(list, item))},
    selection: caretOnceGone(document, {...idsIn(item)}),
  );
}

/// A new empty item in [list], last unless [first]: with an open box
/// where the list's items have boxes.
Edit addItem(ShownDocument document, ListBlock list, {bool first = false}) {
  final id = document.tree.freshBlockIds.first;
  final item = ItemDraft(
    id,
    const [],
    checked: list.items.any((item) => item.hasBox) ? false : null,
  );
  return Edit(
    replaced: {
      list.id: [
        ListDraft.of(list, [
          if (first) item,
          ...kept(list.items),
          if (!first) item,
        ]),
      ],
    },
    selection: TextSelection.caret(Place(ItemSlot(id), 0)),
  );
}

/// [item] with its subitems moved right before [target], or after it if
/// [below], in [target]'s list, taking that list's kind; the selection
/// stays.
Edit moveItem(
  ShownDocument document,
  ItemBlock item,
  ItemBlock target, {
  required bool below,
  required Selection selection,
}) {
  final tree = document.tree;
  final from = tree.parentOf(item)! as ListBlock;
  final to = tree.parentOf(target)! as ListBlock;
  assert(!idsIn(item).contains(target.id), 'an item moves outside itself');
  final moved = [
    for (final other in itemsWithout(to, item))
      if (other.id == target.id) ...[
        if (!below) KeptDraft(item),
        other,
        if (below) KeptDraft(item),
      ] else
        other,
  ];
  return Edit(
    replaced: {
      if (from.id != to.id) from.id: listWith(from, itemsWithout(from, item)),
      to.id: [ListDraft.of(to, moved)],
    },
    selection: selection,
  );
}

/// The checked items at the top level of the document's lists (or only of
/// [list]): those the Done sections show, and the checked-items actions
/// act on.
List<ItemBlock> checkedItems(ShownDocument document, {ListBlock? list}) => [
  for (final top in list == null ? _topLists(document.tree.root) : [list])
    ...top.items.where((item) => item.checked ?? false),
];

/// [items] with their subitems gone: "Clear checked items"; the
/// selection kept if its text stays, else as for [deleteItem].
Edit clearItems(
  ShownDocument document,
  List<ItemBlock> items,
  Selection selection,
) {
  final gone = {for (final item in items) item.id};
  return Edit(
    replaced: {
      for (final list in _listsOf(document, items))
        list.id: [
          if (list.items.any((item) => !gone.contains(item.id)))
            ListDraft.of(list, [
              for (final item in list.items)
                if (!gone.contains(item.id)) KeptDraft(item),
            ]),
        ],
    },
    selection: selectionOnceGone(document, selection, {
      for (final item in items) ...idsIn(item),
    }),
  );
}

/// [items] moved, with their subitems, to the end of their lists in
/// their order: "Move checked items to end", and checks settling.
Edit moveToEnd(
  ShownDocument document,
  List<ItemBlock> items,
  Selection selection,
) {
  final moving = {for (final item in items) item.id};
  return Edit(
    replaced: {
      for (final list in _listsOf(document, items))
        list.id: [
          ListDraft.of(list, [
            for (final item in list.items)
              if (!moving.contains(item.id)) KeptDraft(item),
            for (final item in list.items)
              if (moving.contains(item.id)) KeptDraft(item),
          ]),
        ],
    },
    selection: selection,
  );
}

/// The lists [items] are in.
Iterable<ListBlock> _listsOf(ShownDocument document, List<ItemBlock> items) => {
  for (final item in items) document.tree.parentOf(item)! as ListBlock,
};

/// The lists in [container] that are in no item.
Iterable<ListBlock> _topLists(ContainerBlock container) =>
    container.children.expand(
      (child) => switch (child) {
        final ListBlock list => [list],
        final QuoteBlock quote => _topLists(quote),
        _ => const <ListBlock>[],
      },
    );
