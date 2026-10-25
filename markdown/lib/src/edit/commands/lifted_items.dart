import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../write/draft.dart';
import '../shown/rows.dart';
import '../shown/shown_document.dart';
import '../shown/slot.dart';
import 'outline.dart';

/// The drafts [list] becomes with its [lifted] items out of it: their
/// blocks in the list's place, between the parts of the list around
/// them; an item's own text place a paragraph there with the text it
/// shows in [document], which [moved] maps it to. The first part keeps the list's id; later ones
/// take ids from [fresh] and go on counting.
({List<Draft> drafts, Map<Slot, Slot> moved}) liftedOut(
  ShownDocument document,
  ListBlock list,
  Set<BlockId> lifted,
  Iterator<BlockId> fresh,
) {
  final runs = list.items
      .splitBetween((a, b) => lifted.contains(a.id) || lifted.contains(b.id))
      .toList();
  final keeping = runs.indexWhere((run) => !lifted.contains(run.first.id));
  final places = {
    for (final item in list.items)
      if (lifted.contains(item.id) && ownsSlot(item))
        item.id: (fresh..moveNext()).current,
  };
  final drafts = [
    for (final (index, run) in runs.indexed)
      if (lifted.contains(run.first.id)) ...[
        if (places[run.single.id] case final id?)
          TextDraft(id, document.textOf(ItemSlot(run.single.id))),
        ...kept(run.single.children),
      ] else
        ListDraft(
          index == keeping ? list.id : (fresh..moveNext()).current,
          kept(run),
          kind: list.kind,
          loose: list.loose,
          numbering: list.numbering,
          start: switch (list.numbering) {
            Numbering.sequential =>
              (list.items.first.marker.number ?? 1) +
                  list.items.indexOf(run.first),
            Numbering.same => list.items.first.marker.number ?? 1,
          },
          from: list,
        ),
  ];
  return (
    drafts: drafts,
    moved: {
      for (final MapEntry(key: item, value: id) in places.entries)
        ItemSlot(item): LeafSlot(id),
    },
  );
}
