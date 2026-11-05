import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import 'rows.dart';

/// The leaf of the first row of [after] that shows otherwise than in
/// [before]: another leaf there, its text rebuilt, or the blocks around
/// it changed (an item's box or level, a list's kind, a quote). Where
/// rows only went at the end, the last row left. `null` where every row
/// shows as before. Nodes an edit left untouched are the very same
/// objects, so no row is compared beyond the first change.
NodeId? firstChangedRow(ViewRows before, ViewRows after) {
  final (was, now) = (before.rows, after.rows);
  bool alike(int index) =>
      identical(was[index].leaf, now[index].leaf) &&
      _framedAlike(before.doc, after.doc, now[index].leaf.id);
  final shared = math.min(was.length, now.length);
  final changed =
      Iterable<int>.generate(shared).firstWhereOrNull((i) => !alike(i)) ??
      (was.length == now.length ? null : shared);
  return switch (changed) {
    final index? when now.isNotEmpty =>
      now[math.min(index, now.length - 1)].leaf.id,
    _ => null,
  };
}

/// Whether [leaf] is in the same blocks in [before] as in [after], as
/// they show around it; their other content is not compared.
bool _framedAlike(DocTree before, DocTree after, NodeId leaf) {
  final (was, now) = (before.pathOf(leaf), after.pathOf(leaf));
  return was.length == now.length &&
      IterableZip<DocContainer>([was, now]).every(
        (pair) => switch ((pair[0], pair[1])) {
          (final ItemNode a, final ItemNode b) =>
            a.id == b.id && a.checked == b.checked,
          (final ListNode a, final ListNode b) =>
            a.id == b.id &&
                a.kind == b.kind &&
                a.numbering == b.numbering &&
                a.start == b.start,
          (final a, final b) => a.runtimeType == b.runtimeType && a.id == b.id,
        },
      );
}
