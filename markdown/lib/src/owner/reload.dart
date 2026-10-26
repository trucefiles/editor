/// A document read anew from text, with what Visual edit showed mapped
/// onto it.
library;

import 'package:collection/collection.dart';
import 'package:diffutil_dart/diffutil.dart';

import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../doc/load.dart';
import '../doc/origin.dart';
import '../edit/change.dart';
import '../edit/selection.dart';
import '../print/printer.dart';
import '../tree/inlines.dart';
import '../view/rows.dart';

/// A document read from text: its doc tree, where it was read from, and
/// its print (the text, with the lines each leaf is on).
typedef Loaded = ({DocTree doc, Origin origin, PrintedMarkdown printed});

/// [text] read as a document.
Loaded loaded(String text) {
  final (:doc, :origin) = loadMarkdown(text);
  return (doc: doc, origin: origin, printed: printMarkdown(doc, origin));
}

/// [selection], made in a document printed as [before], as it falls in
/// [after] (shown as [view] shows it): each place goes to the line its
/// leaf started on, through a line diff of the two texts; a line gone
/// takes the nearest line before it that stayed. On that line's leaf the
/// place keeps its offset, clamped; a place whose line went entirely
/// goes to the start of the document.
Selection mappedSelection(
  Selection selection,
  PrintedMarkdown before,
  Loaded after,
  ViewRows view,
) {
  final lines = _newLines(
    before.text.split(lineEnd),
    after.printed.text.split(lineEnd),
  );
  final leaves = after.printed.lines.entries
      .where((entry) => view.rowOf(entry.key) != null)
      .sortedBy<num>((entry) => entry.value.first);
  NodeId? leafAt(NodeId leaf) {
    final line = switch (before.lines[leaf]) {
      final range? =>
        lines.take(range.first + 1).lastWhereOrNull((line) => line != null),
      null => null,
    };
    if (line == null) return null;
    return leaves.lastWhereOrNull((entry) => entry.value.first <= line)?.key ??
        leaves.firstOrNull?.key;
  }

  Place? placed(Place place) => switch (leafAt(place.leaf)) {
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
    BlockSelection(:final block) => switch (leafAt(block)) {
      final leaf? when view.row(leaf) is BlockRow => BlockSelection(leaf),
      final leaf? => TextSelection.caret(Place(leaf, 0)),
      null => startOf(view),
    },
  };
}

/// For each line of [old], the index of the same line in [updated]; `null`
/// for a line [updated] doesn't keep.
///
/// Relies on diffutil's edit script without moves running from the end
/// of the old list, so every position is one in the old list (pinned by
/// the reload tests, as in the app's `diffutil_order_test.dart`).
List<int?> _newLines(List<String> old, List<String> updated) {
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
