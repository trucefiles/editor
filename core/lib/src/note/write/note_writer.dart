import 'package:collection/collection.dart';

import '../lines/line_change.dart';
import '../note_tree.dart';
import 'block/block_writer.dart';
import 'draft.dart';
import 'draft_check.dart';

/// [tree] with [draft]'s blocks: the lines that write them, read again.
/// Only the lines that differ change; blocks read anew take the draft's
/// ids. The tree read holds what the draft says.
NoteTree written(NoteTree tree, RootDraft draft) {
  final (:lines, :planned) = writeLines(tree, draft);
  final olds = [for (final line in tree.lines) (id: line.id, text: line.text)];
  final head = _sameAtStart(lines, olds);
  final tail = _sameAtStart(
    lines.skip(head).toList().reversed,
    olds.skip(head).toList().reversed,
  );
  final result = tree.changed(
    LineChange(
      head,
      olds.length - tail,
      lines.sublist(head, lines.length - tail),
    ),
    planned: planned,
  );
  assert(holdsDraft(result.root, draft), 'the lines written read as drafted');
  return result;
}

/// How many lines [a] and [b] have equal at their start.
int _sameAtStart(Iterable<NewLine> a, Iterable<NewLine> b) =>
    IterableZip([a, b]).takeWhile((pair) => pair[0] == pair[1]).length;
