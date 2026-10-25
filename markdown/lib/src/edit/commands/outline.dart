import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../write/draft.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
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
Row rowOfSlot(ShownDocument document, Slot slot) =>
    document.rows[document.rowOf(slot)!];

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

/// [selection] once the [gone] blocks are: kept where all it is on
/// stays, else as [caretOnceGone].
Selection selectionOnceGone(
  ShownDocument document,
  Selection selection,
  Set<BlockId> gone,
) {
  final rows = switch (selection) {
    TextSelection(:final base, :final extent) => [
      document.rowOf(base.slot),
      document.rowOf(extent.slot),
    ],
    BlockSelection(:final block) => [document.blockRowOf(block)],
  };
  return rows.any((row) => row == null || _goes(document.rows[row], gone))
      ? caretOnceGone(document, gone)
      : selection;
}

/// Where the caret goes once the [gone] blocks are: at the start of the
/// next text shown after the first of them, else at the end of the text
/// above (the end gap only if there is neither, as it may go with them).
TextSelection caretOnceGone(ShownDocument document, Set<BlockId> gone) {
  bool stays(Row row) =>
      row is TextRow &&
      row.slot != const GapSlot(GapId.end) &&
      !_goes(row, gone);
  final rows = document.rows;
  final first = rows.indexWhere((row) => _goes(row, gone));
  return switch ((
    rows.skip(first).firstWhereOrNull(stays),
    rows.take(first).lastWhereOrNull(stays),
  )) {
    (TextRow(:final slot), _) => TextSelection.caret(Place(slot, 0)),
    (_, TextRow(:final slot)) => TextSelection.caret(
      Place(slot, document.textOf(slot).length),
    ),
    _ => const TextSelection.caret(Place(GapSlot(GapId.end), 0)),
  };
}

/// Whether [row] goes with the [gone] blocks.
bool _goes(Row row, Set<BlockId> gone) =>
    row.path.any((block) => gone.contains(block.id)) ||
    switch (row) {
      TextRow(slot: LeafSlot(:final leaf)) => gone.contains(leaf),
      BlockRow(:final leaf) => gone.contains(leaf.id),
      TextRow() => false,
    };
