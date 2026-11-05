import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart' show splitLines, unchangedEnds;

import '../doc/doc_nodes.dart';
import 'printer.dart';

/// The leaf that printed the first line of [after] that differs from
/// [before]; where lines only went, the leaf printed next, else the last
/// one. `null` where both print the same. Printed lines say it however
/// the two trees were made (an edit, or a text read anew).
NodeId? firstChangedLeaf(PrintedMarkdown before, PrintedMarkdown after) {
  if (before.text == after.text) return null;
  final line = unchangedEnds(
    splitLines(before.text),
    splitLines(after.text),
  ).start;
  final leaves = after.lines.entries.sortedBy<num>((leaf) => leaf.value.first);
  return (leaves.firstWhereOrNull((leaf) => leaf.value.last >= line) ??
          leaves.lastOrNull)
      ?.key;
}
