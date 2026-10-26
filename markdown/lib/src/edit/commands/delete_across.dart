import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';
import '../text_places.dart';

/// The text from [start] to [end], in two text places in that order,
/// removed: what shows between goes whole; the two places join (code
/// never joins: each keeps its rest, and code at the end that the range
/// covers to its end goes whole); what was nested under the end's items
/// (later blocks, subitems) moves right after the start's text, under
/// its item.
Change deleteAcross(ViewRows view, Place start, Place end) {
  final doc = view.doc;
  final rows = view.rows;
  final (first, last) = (view.rowOf(start.leaf)!, view.rowOf(end.leaf)!);
  final inRange = rows.sublist(first + 1, last + 1);
  final head = textAt(doc, start.leaf).slice(0, start.offset);
  final rest = textAt(doc, end.leaf);
  final restAfter = rest.slice(end.offset, rest.length);
  final ranges = _rowRanges(doc, rows);
  bool inside(NodeId container) => switch (ranges[container]) {
    (final from, final to) => from > first && to <= last,
    null => false,
  };
  // The leaves of [gone] rows go, and the containers all of whose rows
  // are in the range.
  Set<NodeId> goneWith(List<Row> gone) => {
    for (final row in gone) ...[
      row.leaf.id,
      for (final container in doc.pathOf(row.leaf.id))
        if (inside(container.id)) container.id,
    ],
  };
  DocLeaf leaf(NodeId id) => doc.nodeOf(id)! as DocLeaf;
  final startLeaf = leaf(start.leaf);
  final endLeaf = leaf(end.leaf);
  final caret = TextSelection.caret(start);
  if (startLeaf is CodeNode || endLeaf is CodeNode) {
    final codeGoes = endLeaf is CodeNode && restAfter.isEmpty;
    final gone = goneWith(
      codeGoes ? inRange : inRange.take(inRange.length - 1).toList(),
    );
    return (
      doc: doc.edited({
        for (final id in gone) id: const [],
        start.leaf: [withLeafText(startLeaf, head)],
        if (!codeGoes) end.leaf: [withLeafText(endLeaf, restAfter)],
      }),
      selection: caret,
    );
  }
  // Items whose start went, holding what follows the end: their blocks
  // move, innermost first.
  final endPath = doc.pathOf(end.leaf);
  final dissolved = [
    for (final container in endPath.reversed)
      if (container is ItemNode &&
          !inside(container.id) &&
          ranges[container.id]!.$1 > first)
        container,
  ];
  final gone = goneWith(inRange);
  final goneOrMoved = {...gone, ...dissolved.map((item) => item.id)};
  final removals = {for (final id in goneOrMoved) id: const <DocBlock>[]};
  final moved = [
    for (final item in dissolved)
      for (final child in item.children)
        if (!gone.contains(child.id)) ...editedIn(child, removals),
  ];
  final startPath = doc.pathOf(start.leaf);
  final under = startPath.lastWhereOrNull((node) => node is ItemNode);
  final startParent = startPath.last;
  // What moves goes right after the start's text in its item; where the
  // text is deeper in it (in a quote), right after that block.
  final outer = under != null && startParent.id != under.id
      ? startPath[startPath.indexOf(under) + 1]
      : null;
  final (point, parent) = outer != null
      ? (outer, under!)
      : (startLeaf as DocBlock, startParent);
  final next = parent.children
      .skipWhile((child) => child.id != point.id)
      .skip(1)
      .firstWhereOrNull((child) => !goneOrMoved.contains(child.id));
  final merged = _mergedWithNext(moved, next, goneOrMoved);
  final joined = withLeafText(startLeaf, head + restAfter);
  return (
    doc: doc.edited({
      ...removals,
      if (!identical(merged, moved)) next!.id: const [],
      if (outer != null)
        outer.id: [
          ...editedIn(outer, {
            ...removals,
            start.leaf: [joined],
          }),
          ...merged,
        ]
      else
        start.leaf: [joined, ...merged],
    }),
    selection: caret,
  );
}

/// [moved] with its last list joined by [next], a list of its kind right
/// after it, so they stay one list; [moved] itself otherwise. [next]'s
/// items in [gone] go or moved elsewhere.
List<DocBlock> _mergedWithNext(
  List<DocBlock> moved,
  DocBlock? next,
  Set<NodeId> gone,
) => switch ((moved.lastOrNull, next)) {
  (final ListNode last, final ListNode next) when last.kind == next.kind => [
    ...moved.take(moved.length - 1),
    last.withChildren([
      ...last.items,
      ...next.items.where((item) => !gone.contains(item.id)),
    ]),
  ],
  _ => moved,
};

/// The first and last row each container of [doc] shows in.
Map<NodeId, (int, int)> _rowRanges(DocTree doc, List<Row> rows) {
  final ranges = <NodeId, (int, int)>{};
  for (final (index, row) in rows.indexed) {
    for (final container in doc.pathOf(row.leaf.id)) {
      final range = ranges[container.id];
      ranges[container.id] = (range?.$1 ?? index, index);
    }
  }
  return ranges;
}
