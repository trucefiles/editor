import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../write/draft.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';

/// The child of [container] right before [block]; `null` if it is first.
Block? blockBefore(ContainerBlock container, Block block) =>
    container.children.takeWhile((child) => child.id != block.id).lastOrNull;

/// [gaps] with [gap] among those shown after the same block: [first]
/// among them, else last.
List<Gap> withGap(List<Gap> gaps, Gap gap, {required bool first}) {
  final peers = [
    for (final (index, other) in gaps.indexed)
      if (other.container == gap.container && other.after == gap.after) index,
  ];
  final at = peers.isEmpty
      ? gaps.length
      : first
      ? peers.first
      : peers.last + 1;
  return [...gaps.take(at), gap, ...gaps.skip(at)];
}

/// The row [slot] shows in.
Row rowOfSlot(ShownNote note, Slot slot) => note.rows[note.rowOf(slot)!];

/// The kept drafts of [blocks].
List<Draft> kept(Iterable<Block> blocks) => [...blocks.map(KeptDraft.new)];

/// [list] holding [items] instead: none if it holds none, so it goes.
List<Draft> listWith(ListBlock list, List<Draft> items) => [
  if (items.isNotEmpty) ListDraft.of(list, items),
];

/// [list]'s items but [item], kept.
List<Draft> itemsWithout(ListBlock list, ItemBlock item) => [
  for (final other in list.items)
    if (other.id != item.id) KeptDraft(other),
];

/// Where the caret goes once the [gone] blocks are: at the start of the
/// next text shown after the first of them, else at the end of the text
/// above (the end gap only if there is neither, as it may go with them).
TextSelection caretOnceGone(ShownNote note, Set<BlockId> gone) {
  bool goes(Row row) =>
      row.path.any((block) => gone.contains(block.id)) ||
      switch (row) {
        TextRow(slot: LeafSlot(:final leaf)) => gone.contains(leaf),
        BlockRow(:final leaf) => gone.contains(leaf.id),
        TextRow() => false,
      };
  bool stays(Row row) =>
      row is TextRow && row.slot != const GapSlot(GapId.end) && !goes(row);
  final rows = note.rows;
  final first = rows.indexWhere(goes);
  return switch ((
    rows.skip(first).firstWhereOrNull(stays),
    rows.take(first).lastWhereOrNull(stays),
  )) {
    (TextRow(:final slot), _) => TextSelection.caret(Place(slot, 0)),
    (_, TextRow(:final slot)) => TextSelection.caret(
      Place(slot, note.textOf(slot).length),
    ),
    _ => const TextSelection.caret(Place(GapSlot(GapId.end), 0)),
  };
}
