import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../tree/blocks.dart';

/// The nodes [list] becomes with its [lifted] items out of it: their
/// blocks in the list's place, between the parts of the list around
/// them. The first part keeps the list's id; later ones take ids from
/// [fresh] and go on counting.
List<DocBlock> liftedOut(ListNode list, Set<NodeId> lifted, FreshIds fresh) {
  final runs = list.items
      .splitBetween((a, b) => lifted.contains(a.id) || lifted.contains(b.id))
      .toList();
  final keeping = runs.indexWhere((run) => !lifted.contains(run.first.id));
  return [
    for (final (index, run) in runs.indexed)
      if (lifted.contains(run.first.id))
        ...run.single.children
      else if (index == keeping)
        list.withChildren(run)
      else
        listPart(list, run, fresh),
  ];
}

/// A new list of [list]'s kind and style holding [items], some of its
/// items, with an id from [fresh]; it goes on counting where they were.
ListNode listPart(ListNode list, List<ItemNode> items, FreshIds fresh) =>
    ListNode(
      fresh.take(),
      items,
      kind: list.kind,
      numbering: list.numbering,
      start: switch (list.numbering) {
        Numbering.sequential => list.start + list.items.indexOf(items.first),
        Numbering.same => list.start,
      },
      source: list.source,
    );
