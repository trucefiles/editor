import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../write/draft.dart';
import '../shown/rows.dart';
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
