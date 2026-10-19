import 'block.dart';
import 'line_id.dart';
import 'markdown_line.dart';
import 'markdown_lines.dart';
import 'syntax/block_syntax.dart';
import 'syntax/line_kinds.dart';

extension ListConversion on MarkdownLines {
  /// Turns the lines [ids] into items of [kind], as a list button in a
  /// text editor does: text lines become items at the left margin, items
  /// of another kind keep their level and text. If all of them are items
  /// of [kind] already, they become text again. Only list items and text
  /// lines change; headings, quotes, code and tables stay as they are.
  ///
  /// With no line to change, it adds an empty item of [kind]: below the
  /// last of [ids] if that is a heading or quote, else at the end, keeping
  /// a final line break. Returns the new document and that added item's
  /// line, if any.
  (MarkdownLines, LineId?) toList(List<LineId> ids, ListKind kind) {
    final lines = [
      for (final id in ids)
        if (lineOf(id) case final line? when _converts(line)) line,
    ];
    if (lines.isEmpty) {
      final below = ids.isEmpty ? null : lineOf(ids.last);
      final (added, id) = below != null && kindOf(below) == LineKind.plain
          ? _addBelow(below, kind)
          : _addAtEnd(kind);
      return (added, id);
    }
    final back = lines.every((line) => line.listKind == kind);
    var converted = this;
    for (final line in lines) {
      converted = converted.withBlock(
        line.id,
        back
            ? TextBlock(line.text)
            : ItemBlock(
                kind: kind,
                depth: isItem(line) ? depthOf(line) : 0,
                text: isItem(line) ? line.text : line.raw.trimLeft(),
                checked: line.isChecked,
              ),
      );
    }
    return (converted, null);
  }

  bool _converts(MarkdownLine line) =>
      kindOf(line) == LineKind.plain &&
      (isItem(line) ||
          (headingMark(line.raw) == null && quoteTextStart(line.raw) == null));

  /// An empty item of [kind] on a new line below [line].
  (MarkdownLines, LineId) _addBelow(MarkdownLine line, ListKind kind) {
    final index = lines.indexOf(line);
    final (added, ids) = insertBlocks(
      [ItemBlock(kind: kind, depth: 0, text: '')],
      after: line.id,
      shownBelow: index + 1 < lines.length ? lines[index + 1].id : null,
    );
    return (added, ids.single);
  }

  /// An empty item of [kind] at the end: on the last line if it is the
  /// only one and blank, else on a new line, before a final line break.
  (MarkdownLines, LineId) _addAtEnd(ListKind kind) {
    final empty = ItemBlock(kind: kind, depth: 0, text: '');
    if (text.isEmpty) {
      return (withBlock(lines.single.id, empty), lines.single.id);
    }
    final finalBreak = lines.length > 1 && lines.last.raw.isEmpty;
    final last = lines[lines.length - (finalBreak ? 2 : 1)];
    final (added, ids) = insertBlocks(
      [empty],
      after: last.id,
      shownBelow: finalBreak ? lines.last.id : null,
    );
    return (added, ids.single);
  }
}
