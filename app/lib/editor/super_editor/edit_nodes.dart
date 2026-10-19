import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'display_nodes.dart';
import 'line_nodes.dart';

/// The nodes for [entries] of [document] in an editing mode: each line
/// as its raw text in a paragraph; in [visual] edit, checkbox items as
/// tasks with the text after the box, plus the "Done" headings, add
/// buttons and drawn tables and images.
List<DocumentNode> editNodes(
  List<DisplayEntry> entries,
  MarkdownLines document,
  LineNodes ids, {
  required bool visual,
}) {
  final byId = {for (final line in document.lines) line.id: line};
  return [
    for (final entry in entries)
      switch (entry) {
        LineEntry(:final id, :final kind) => _lineNode(
          byId[id]!,
          document,
          ids.nodeOf(id),
          asTask: visual && kind == LineKind.plain && byId[id]!.isItem,
        ),
        DoneHeadingEntry() => DoneHeadingNode(entry),
        AddItemEntry() => AddItemNode(entry),
        TableEntry(:final ids) => DrawnTableNode([
          for (final id in ids) byId[id]!,
        ]),
        ImageEntry(:final id) => DrawnImageNode(byId[id]!, entry),
      },
  ];
}

DocumentNode _lineNode(
  MarkdownLine line,
  MarkdownLines document,
  String id, {
  required bool asTask,
}) => asTask
    ? TaskNode(
        id: id,
        text: AttributedText(line.text),
        isComplete: line.isChecked,
        indent: document.depthOf(line),
      )
    : ParagraphNode(id: id, text: AttributedText(line.raw));

/// What the editor shows in [node], if it is a line.
Block? blockOf(DocumentNode node) => switch (node) {
  TaskNode(:final isComplete, :final indent, :final text) => ItemBlock(
    checked: isComplete,
    depth: indent,
    text: text.toPlainText(),
  ),
  TextNode(:final text) => TextBlock(text.toPlainText()),
  _ => null,
};
