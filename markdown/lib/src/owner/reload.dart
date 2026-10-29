/// A document read anew from text, with what Visual edit showed mapped
/// onto it.
library;

import 'package:collection/collection.dart';
import 'package:diffutil_dart/diffutil.dart';
import 'package:truce_core/truce_core.dart' show splitLines;

import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../doc/load.dart';
import '../doc/origin.dart';
import '../edit/change.dart';
import '../edit/selection.dart';
import '../print/printer.dart';
import '../view/rows.dart';

/// A document read from text: its doc tree, where it was read from, and
/// its print (the text, with the lines each leaf is on).
typedef Loaded = ({DocTree doc, Origin origin, PrintedMarkdown printed});

/// [text] read as a document.
Loaded loaded(String text) {
  final (:doc, :origin) = loadMarkdown(text);
  return (doc: doc, origin: origin, printed: printMarkdown(doc, origin));
}

/// What showed before a reload, as it falls in the document read anew:
/// through a line diff of the old print, [before], and the new, of
/// [after].
final class ReloadMap {
  ReloadMap(this.before, this.after)
    : _newLines = _newLinesOf(
        splitLines(before.text),
        splitLines(after.printed.text),
      );

  final PrintedMarkdown before;
  final Loaded after;

  /// For each old line, its line in the new print; `null` if gone.
  final List<int?> _newLines;

  /// The leaf shown in [view] that old leaf [leaf] falls on: the one on
  /// the line [leaf] started on; a line gone takes the nearest line
  /// before it that stayed. `null` if every line up to it went.
  NodeId? leafOf(NodeId leaf, ViewRows view) {
    final line = switch (before.lines[leaf]) {
      final range? =>
        _newLines.take(range.first + 1).lastWhereOrNull((line) => line != null),
      null => null,
    };
    if (line == null) return null;
    final leaves = after.printed.lines.entries
        .where((entry) => view.rowOf(entry.key) != null)
        .sortedBy<num>((entry) => entry.value.first);
    return leaves.lastWhereOrNull((entry) => entry.value.first <= line)?.key ??
        leaves.firstOrNull?.key;
  }

  /// [selection] as it falls in [after], shown as [view] shows it: each
  /// place on the leaf its leaf falls on ([leafOf]), keeping its offset,
  /// clamped; a selected divider stays selected; anything else lands at
  /// the start of a text it falls on, else of the document.
  Selection selection(Selection selection, ViewRows view) {
    Place? placed(Place place) => switch (leafOf(place.leaf, view)) {
      final leaf? when view.row(leaf) is TextRow => Place(
        leaf,
        place.offset.clamp(0, textOf(view.row(leaf)!.leaf).length),
      ),
      _ => null,
    };
    return switch (selection) {
      TextSelection(:final base, :final extent) => switch ((
        placed(base),
        placed(extent),
      )) {
        (final base?, final extent?) => TextSelection(base, extent),
        _ => startOf(view),
      },
      BlockSelection(:final block) => switch (leafOf(block, view)) {
        final leaf? when view.row(leaf)?.leaf is DividerNode => BlockSelection(
          leaf,
        ),
        final leaf? when view.row(leaf) is TextRow => TextSelection.caret(
          Place(leaf, 0),
        ),
        _ => startOf(view),
      },
    };
  }

  /// [lists] of [old] as lists of [after], each by its first line: one
  /// whose first line is gone, or where no list starts now, goes. Where
  /// lists start on one line, the outermost is it.
  Set<NodeId> lists(Set<NodeId> lists, DocTree old) {
    final startingAt = {
      for (final list in nodesIn(
        after.doc.root,
      ).whereType<ListNode>().toList().reversed)
        ?_firstLine(list, after.printed): list.id,
    };
    return {
      for (final id in lists)
        if (old.nodeOf(id) case final ListNode list)
          if (_firstLine(list, before) case final line?)
            if (_newLines[line] case final now?) ?startingAt[now],
    };
  }
}

/// The line [list] starts on in [printed]: its first leaf's.
int? _firstLine(ListNode list, PrintedMarkdown printed) =>
    switch (leavesIn(list).firstOrNull) {
      final leaf? => printed.lines[leaf.id]?.first,
      null => null,
    };

/// For each line of [old], the index of the same line in [updated]; `null`
/// for a line [updated] doesn't keep.
///
/// Relies on diffutil's edit script without moves running from the end
/// of the old list, so every position is one in the old list (pinned by
/// the reload tests, as in the app's `diffutil_order_test.dart`).
List<int?> _newLinesOf(List<String> old, List<String> updated) {
  final script = calculateListDiff(
    old,
    updated,
    detectMoves: false,
  ).getUpdates(batch: false).toList();
  final removed = {
    for (final update in script.whereType<Remove>())
      for (var line = 0; line < update.count; line++) update.position + line,
  };
  final insertedAt = [
    for (final update in script.whereType<Insert>())
      for (var line = 0; line < update.count; line++) update.position,
  ];
  final kept = [
    for (var line = 0; line < old.length; line++)
      if (!removed.contains(line)) line,
  ];
  final keptBefore = {for (final (index, line) in kept.indexed) line: index};
  return [
    for (var line = 0; line < old.length; line++)
      switch (keptBefore[line]) {
        final index? =>
          index + insertedAt.where((position) => position <= line).length,
        null => null,
      },
  ];
}
