import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../write/draft.dart';
import '../commit.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';
import 'outline.dart';

/// [item]'s box checked or unchecked; the selection stays.
Edit toggle(ShownNote note, ItemBlock item, Selection selection) => Edit(
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
Edit deleteItem(ShownNote note, ItemBlock item) {
  final list = note.tree.parentOf(item)! as ListBlock;
  final rows = note.rows;
  final inside = {for (final id in idsIn(item)) id};
  bool shown(Row row) =>
      row is TextRow && !row.path.any((block) => inside.contains(block.id));
  final first = rows.indexWhere(
    (row) => row.path.any((block) => block.id == item.id),
  );
  final after = rows.skip(first).firstWhereOrNull(shown);
  final before = rows.take(first).lastWhereOrNull(shown);
  return Edit(
    replaced: {list.id: listWith(list, itemsWithout(list, item))},
    selection: switch ((after, before)) {
      (TextRow(:final slot), _) => TextSelection.caret(Place(slot, 0)),
      (_, TextRow(:final slot)) => TextSelection.caret(
        Place(slot, note.textOf(slot).length),
      ),
      _ => const TextSelection.caret(Place(GapSlot(GapId.end), 0)),
    },
  );
}

/// A new empty item in [list], last unless [first]: with an open box
/// where the list's items have boxes.
Edit addItem(ShownNote note, ListBlock list, {bool first = false}) {
  final id = note.tree.freshBlockIds.first;
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
  ShownNote note,
  ItemBlock item,
  ItemBlock target, {
  required bool below,
  required Selection selection,
}) {
  final tree = note.tree;
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

/// The checked items at the top level of the note's lists (or only of
/// [list]): those the Done sections show, and the checked-items actions
/// act on.
List<ItemBlock> checkedItems(ShownNote note, {ListBlock? list}) => [
  for (final top in list == null ? _topLists(note.tree.root) : [list])
    ...top.items.where((item) => item.checked ?? false),
];

/// [items] with their subitems gone: "Clear checked items".
Edit clearItems(ShownNote note, List<ItemBlock> items, Selection selection) {
  final gone = {for (final item in items) item.id};
  return Edit(
    replaced: {
      for (final list in _listsOf(note, items))
        list.id: [
          if (list.items.any((item) => !gone.contains(item.id)))
            ListDraft.of(list, [
              for (final item in list.items)
                if (!gone.contains(item.id)) KeptDraft(item),
            ]),
        ],
    },
    selection: selection,
  );
}

/// [items] moved, with their subitems, to the end of their lists in
/// their order: "Move checked items to end", and checks settling.
Edit moveToEnd(ShownNote note, List<ItemBlock> items, Selection selection) {
  final moving = {for (final item in items) item.id};
  return Edit(
    replaced: {
      for (final list in _listsOf(note, items))
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
Iterable<ListBlock> _listsOf(ShownNote note, List<ItemBlock> items) => {
  for (final item in items) note.tree.parentOf(item)! as ListBlock,
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
