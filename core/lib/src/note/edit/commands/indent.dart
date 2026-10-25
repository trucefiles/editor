import '../../tree/blocks.dart';
import '../../write/draft.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';
import 'lifted_items.dart';
import 'outline.dart';
import 'remove_frame.dart';

/// The item [slot] is in, as an item, outside a Done section: what
/// indent and outdent act on; `null` if there is none.
ItemBlock? itemAt(ShownNote note, Slot slot) {
  final row = rowOfSlot(note, slot);
  if (row.done) return null;
  return switch (row.path.lastOrNull) {
    final ItemBlock item => item,
    _ => null,
  };
}

/// Whether the item at [slot] can be indented: it has an item above it
/// in its list.
bool canIndent(ShownNote note, Slot slot) => switch (itemAt(note, slot)) {
  final item? =>
    (note.tree.parentOf(item)! as ListBlock).items.first.id != item.id,
  null => false,
};

/// Whether the item at [slot] can be outdented: it is in an item.
bool canOutdent(ShownNote note, Slot slot) => itemAt(note, slot) != null;

/// The item at [selection]'s caret made the last child of the item above
/// it, its own children coming along; it joins that item's sublist if
/// it ends with one, taking its kind, else starts one.
Edit indent(ShownNote note, TextSelection selection) {
  final item = itemAt(note, selection.extent.slot)!;
  final list = note.tree.parentOf(item)! as ListBlock;
  final above = list.items[list.items.indexOf(item) - 1];
  return Edit(
    replaced: {
      list.id: [
        ListDraft.of(list, [
          for (final other in list.items)
            if (other.id != item.id) KeptDraft(other),
        ]),
      ],
      above.id: [
        ItemDraft.of(above, switch (above.children.lastOrNull) {
          final ListBlock sublist => [
            ...kept(above.children.take(above.children.length - 1)),
            ListDraft.of(sublist, [...kept(sublist.items), KeptDraft(item)]),
          ],
          _ => [
            ...kept(above.children),
            ListDraft(
              note.tree.freshBlockIds.first,
              [KeptDraft(item)],
              kind: list.kind,
              loose: list.loose,
            ),
          ],
        }),
      ],
    },
    selection: selection,
  );
}

/// The item at [selection]'s caret one level out, right after the item
/// it is in, the items after it in its list becoming its subitems; at a
/// list's top level, its blocks out of the list, which splits around it.
Edit outdent(ShownNote note, TextSelection selection) {
  final item = itemAt(note, selection.extent.slot)!;
  final list = note.tree.parentOf(item)! as ListBlock;
  final parent = note.tree.parentOf(list);
  if (parent is! ItemBlock) {
    if (item.isEmpty) return leaveList(note, selection.extent.slot);
    return Edit(
      replaced: {
        list.id: liftedOut(list, {item.id}, note.tree.freshBlockIds.iterator),
      },
      selection: selection,
    );
  }
  final index = list.items.indexOf(item);
  final following = list.items.skip(index + 1).toList();
  final children = switch ((item.children.lastOrNull, following)) {
    (_, []) => kept(item.children),
    (final ListBlock sublist, _) when sublist.kind == list.kind => [
      ...kept(item.children.take(item.children.length - 1)),
      ListDraft.of(sublist, [...kept(sublist.items), ...kept(following)]),
    ],
    _ => [
      ...kept(item.children),
      ListDraft(
        note.tree.freshBlockIds.first,
        kept(following),
        kind: list.kind,
        loose: list.loose,
        numbering: list.numbering,
      ),
    ],
  };
  return Edit(
    replaced: {
      list.id: [
        if (index > 0) ListDraft.of(list, kept(list.items.take(index))),
      ],
      parent.id: [KeptDraft(parent), ItemDraft.of(item, children)],
    },
    selection: selection,
  );
}
