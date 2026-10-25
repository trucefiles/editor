import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../write/draft.dart';
import 'outline.dart';

/// The drafts [list] becomes with its [lifted] items out of it: their
/// blocks in the list's place, between the parts of the list around
/// them. The first part keeps the list's id; later ones take ids from
/// [fresh] and go on counting.
List<Draft> liftedOut(
  ListBlock list,
  Set<BlockId> lifted,
  Iterator<BlockId> fresh,
) {
  final runs = list.items
      .splitBetween((a, b) => lifted.contains(a.id) || lifted.contains(b.id))
      .toList();
  final keeping = runs.indexWhere((run) => !lifted.contains(run.first.id));
  return [
    for (final (index, run) in runs.indexed)
      if (lifted.contains(run.first.id))
        ...kept(run.single.children)
      else
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
}
