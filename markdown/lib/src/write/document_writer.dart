import 'dart:math';

import 'package:collection/collection.dart';

import '../document_tree.dart';
import '../lines/line_change.dart';
import 'block/block_writer.dart';
import 'draft.dart';
import 'draft_check.dart';

/// [tree] with [draft]'s blocks: the lines that write them, read again.
/// Only the lines that differ change, and those where a new block
/// starts (one the same bytes wrote before, under another id); blocks
/// read anew take the draft's ids. The tree read holds what the draft
/// says.
DocumentTree written(DocumentTree tree, RootDraft draft) {
  final (:lines, :planned) = writeLines(tree, draft);
  final olds = [for (final line in tree.lines) (id: line.id, text: line.text)];
  final newStarts = [
    for (final MapEntry(key: (_, line), value: ids) in planned.entries)
      if (ids.any((id) => tree.blockOf(id) == null)) line,
  ];
  final head = min(
    _sameAtStart(lines, olds),
    newStarts.minOrNull ?? lines.length,
  );
  final tail = min(
    _sameAtStart(
      lines.skip(head).toList().reversed,
      olds.skip(head).toList().reversed,
    ),
    lines.length - 1 - (newStarts.maxOrNull ?? -1),
  );
  final result = tree.changed(
    LineChange(
      head,
      olds.length - tail,
      lines.sublist(head, lines.length - tail),
    ),
    planned: planned,
  );
  assert(
    holdsDraft(result, draft),
    'the lines written read as drafted:\n${result.text}',
  );
  return result;
}

/// How many lines [a] and [b] have equal at their start.
int _sameAtStart(Iterable<NewLine> a, Iterable<NewLine> b) =>
    IterableZip([a, b]).takeWhile((pair) => pair[0] == pair[1]).length;
