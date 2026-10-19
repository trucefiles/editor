import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

/// The markup of each text node of [document], by node id: a task's
/// item text, a paragraph's whole line, of the kind its place among the
/// lines gives it (e.g. inside a code block).
Map<String, List<MarkupSpan>> documentMarkup(Document document) {
  final nodes = [
    for (final node in document)
      if (node is TextNode) node,
  ];
  final kinds = lineKinds([
    // An item is never part of a code block or table.
    for (final node in nodes) node is TaskNode ? '' : node.text.toPlainText(),
  ]);
  return {
    for (final (index, node) in nodes.indexed)
      node.id: node is TaskNode
          ? itemTextMarkup(node.text.toPlainText())
          : lineMarkup(node.text.toPlainText(), kinds[index]),
  };
}
