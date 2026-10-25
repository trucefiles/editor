import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../write/draft.dart';
import '../commit.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import '../shown/slot.dart';
import 'outline.dart';
import 'text_places.dart';

/// The text from [start] to [end], in two text places in that order,
/// removed: what lies between goes whole; the two places join (code
/// never joins: each keeps its rest, and code at the end that the range
/// covers to its end goes whole); what was nested under the end's
/// items (later blocks, subitems) moves right after the start's text,
/// under its item.
Edit deleteAcross(ShownDocument document, Place start, Place end) {
  final tree = document.tree;
  final rows = document.rows;
  final (first, last) = (
    document.rowOf(start.slot)!,
    document.rowOf(end.slot)!,
  );
  final inRange = rows.sublist(first + 1, last + 1);
  final fresh = tree.freshBlockIds.iterator;
  final head = document.textOf(start.slot).slice(0, start.offset);
  final rest = document.textOf(end.slot);
  final restAfter = rest.slice(end.offset, rest.length);
  final ranges = _rowRanges(rows);
  bool inside(BlockId container) => switch (ranges[container]) {
    (final from, final to) => from > first && to <= last,
    null => false,
  };
  // The blocks of [gone] rows go, and the containers all of whose rows
  // are in the range.
  Map<BlockId, List<Draft>> removedWith(List<Row> gone) => {
    for (final row in gone) ?_leafOf(row): const [],
    for (final row in gone)
      for (final container in row.path)
        if (inside(container.id)) container.id: const [],
  };
  List<Gap> gapsWithout(List<Row> gone, [List<Gap>? gaps]) => [
    for (final gap in gaps ?? document.gaps)
      if (!gone.any((row) => row is TextRow && row.slot == GapSlot(gap.id)))
        gap,
  ];
  if (_isCode(document, start.slot) || _isCode(document, end.slot)) {
    final codeGoes = _isCode(document, end.slot) && restAfter.length == 0;
    final changes = [
      withText(document, start.slot, head, fresh),
      if (!codeGoes) withText(document, end.slot, restAfter, fresh),
    ];
    final kept = changes.first;
    final between = codeGoes
        ? inRange
        : inRange.take(inRange.length - 1).toList();
    return Edit(
      replaced: {
        ...removedWith(between),
        for (final change in changes) ...change.replaced,
      },
      gaps: gapsWithout(between),
      tails: {for (final change in changes) ...change.tails},
      selection: TextSelection.caret(Place(kept.slot, start.offset)),
    );
  }
  // Items whose start went, holding what follows the end: their blocks
  // move, innermost first.
  final dissolved = [
    for (final container in rows[last].path.reversed)
      if (container is ItemBlock &&
          !inside(container.id) &&
          ranges[container.id]!.$1 > first)
        container,
  ];
  final gone = removedWith(inRange);
  final moved = [
    for (final item in dissolved)
      for (final child in item.children)
        if (!gone.containsKey(child.id)) KeptDraft(child),
  ];
  final startPath = rows[first].path;
  final under = startPath.lastWhereOrNull((block) => block is ItemBlock);
  final startLeaf = _leafOf(rows[first]);
  final startParent = startLeaf == null
      ? null
      : tree.parentOf(tree.blockOf(startLeaf)!);
  // What moves goes right after the start's text in its item; where the
  // text is deeper in it (in a quote), right after that block.
  final outer =
      under != null && startParent != null && startParent.id != under.id
      ? startPath[startPath.indexOf(under) + 1]
      : null;
  final goneOrMoved = {...gone.keys, ...dissolved.map((item) => item.id)};
  // The block that what moves goes after, in its container.
  final (point, parent) = switch (start.slot) {
    _ when outer != null => (outer, under),
    LeafSlot() => (tree.blockOf(startLeaf!), startParent),
    ItemSlot(:final item) => (null, tree.blockOf(item) as ContainerBlock?),
    GapSlot() => (null, null),
  };
  final next = parent?.children
      .skipWhile((child) => point != null && child.id != point.id)
      .skip(point == null ? 0 : 1)
      .firstWhereOrNull((child) => !goneOrMoved.contains(child.id));
  final merged = _mergedWithNext(moved, next, goneOrMoved);
  final endLeaf = switch (end.slot) {
    LeafSlot(:final leaf) => tree.blockOf(leaf),
    _ => null,
  };
  final joined = withText(
    document,
    start.slot,
    head + restAfter,
    fresh,
    following: outer == null ? merged : const [],
    joined: [if (endLeaf is TextLeaf) endLeaf],
  );
  return Edit(
    replaced: {
      ...gone,
      for (final item in dissolved) item.id: const [],
      if (outer != null) outer.id: [KeptDraft(outer), ...merged],
      if (merged != moved) next!.id: const [],
      ...joined.replaced,
    },
    gaps: gapsWithout(inRange, joined.gaps),
    tails: joined.tails,
    selection: TextSelection.caret(Place(joined.slot, start.offset)),
  );
}

/// [moved] with its last list joined by [next], a list of its kind
/// right after it, so they stay one list; [moved] itself otherwise.
/// [next]'s items in [gone] go or moved elsewhere.
List<Draft> _mergedWithNext(
  List<Draft> moved,
  Block? next,
  Set<BlockId> gone,
) => switch ((moved.lastOrNull, next)) {
  (KeptDraft(block: final ListBlock last), final ListBlock next)
      when last.kind == next.kind =>
    [
      ...moved.take(moved.length - 1),
      ListDraft.of(last, [
        ...kept(last.items),
        ...kept(next.items.where((item) => !gone.contains(item.id))),
      ]),
    ],
  _ => moved,
};

/// The leaf [row] shows; `null` for an item's own place or a gap.
BlockId? _leafOf(Row row) => switch (row) {
  TextRow(slot: LeafSlot(:final leaf)) => leaf,
  TextRow() => null,
  BlockRow(:final leaf) => leaf.id,
};

bool _isCode(ShownDocument document, Slot slot) => switch (slot) {
  LeafSlot(:final leaf) => document.tree.blockOf(leaf) is CodeBlock,
  _ => false,
};

/// The first and last row each container shows in.
Map<BlockId, (int, int)> _rowRanges(List<Row> rows) {
  final ranges = <BlockId, (int, int)>{};
  for (final (index, row) in rows.indexed) {
    for (final container in row.path) {
      final range = ranges[container.id];
      ranges[container.id] = (range?.$1 ?? index, index);
    }
  }
  return ranges;
}
