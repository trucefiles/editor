import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

/// The markup of each text node of [document], by node id: a list item's
/// text after its marker, a paragraph's whole line, of the kind its place among the
/// lines gives it (e.g. inside a code block).
Map<String, List<MarkupSpan>> documentMarkup(Document document) {
  final nodes = [
    for (final node in document)
      if (node is TextNode) node,
  ];
  final kinds = lineKinds([
    // A list item is never part of a code block or table.
    for (final node in nodes) _isItem(node) ? '' : node.text.toPlainText(),
  ]);
  return {
    for (final (index, node) in nodes.indexed)
      node.id: _isItem(node)
          ? itemTextMarkup(node.text.toPlainText())
          : lineMarkup(node.text.toPlainText(), kinds[index]),
  };
}

bool _isItem(TextNode node) => node is TaskNode || node is ListItemNode;
