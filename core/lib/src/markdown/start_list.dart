import 'block.dart';
import 'line_id.dart';
import 'markdown_line.dart';
import 'markdown_lines.dart';

extension StartList on MarkdownLines {
  /// Starts a checklist with an empty item: on line [at] if it is blank,
  /// else on a new line below it, at its level if it is a list item; at the
  /// end if [at] is `null`, keeping a final line break. Returns the new
  /// document and the item's line.
  (MarkdownLines, LineId) startList({LineId? at}) {
    final line = switch (at) {
      final id? => lines.firstWhere((line) => line.id == id),
      null when text.isEmpty => lines.single,
      null when lines.length > 1 && lines.last.raw.isEmpty =>
        lines[lines.length - 2],
      null => lines.last,
    };
    if (line.raw.trim().isEmpty && (at != null || text.isEmpty)) {
      final item = withBlock(
        line.id,
        const ItemBlock(kind: ListKind.checkbox, depth: 0, text: ''),
      );
      return (item, line.id);
    }
    final depth = isItem(line) ? depthOf(line) : 0;
    final (added, ids) = insertBlocks(
      [ItemBlock(kind: ListKind.checkbox, depth: depth, text: '')],
      after: line.id,
      shown: {for (final line in lines) line.id},
    );
    return (added, ids.single);
  }
}
