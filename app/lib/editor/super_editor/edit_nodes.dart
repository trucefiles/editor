import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'display_nodes.dart';
import 'line_nodes.dart';

/// The nodes for [entries] of [document] in an editing mode: each line
/// as its raw text in a paragraph; in [visual] edit, list items as tasks
/// and list items with the text after their marker, plus the "Done"
/// headings, add buttons and drawn tables and images.
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
        LineEntry(:final id) => _lineNode(
          byId[id]!,
          document,
          ids.nodeOf(id),
          asItem: visual && document.isItem(byId[id]!),
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
  required bool asItem,
}) => asItem
    ? itemNode(id, line, AttributedText(line.text), document.depthOf(line))
    : ParagraphNode(id: id, text: AttributedText(line.raw));

/// The node [id] showing the list item [line] at [depth] with [text].
DocumentNode itemNode(
  String id,
  MarkdownLine line,
  AttributedText text,
  int depth,
) => switch (line.listKind!) {
  ListKind.checkbox => TaskNode(
    id: id,
    text: text,
    isComplete: line.isChecked,
    indent: depth,
  ),
  ListKind.bullet => ListItemNode.unordered(id: id, text: text, indent: depth),
  ListKind.numbered => ListItemNode.ordered(id: id, text: text, indent: depth),
};

/// What the editor shows in [node], if it is a line.
Block? blockOf(DocumentNode node) => switch (node) {
  TaskNode(:final isComplete, :final indent, :final text) => ItemBlock(
    kind: ListKind.checkbox,
    checked: isComplete,
    depth: indent,
    text: text.toPlainText(),
  ),
  ListItemNode(:final type, :final indent, :final text) => ItemBlock(
    kind: type == ListItemType.ordered ? ListKind.numbered : ListKind.bullet,
    depth: indent,
    text: text.toPlainText(),
  ),
  TextNode(:final text) => TextBlock(text.toPlainText()),
  _ => null,
};
