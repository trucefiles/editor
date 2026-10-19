import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

/// The markup of each text node of [document], by node id; see
/// [nodeMarkup].
Map<String, List<MarkupSpan>> documentMarkup(
  Document document,
  LineKind Function(String nodeId) kindOf,
) => {
  for (final node in document)
    if (node is TextNode) node.id: nodeMarkup(node, kindOf(node.id)),
};

/// The markup of [node]: a list item's text after its marker, a
/// paragraph's whole line as of its line's [kind] (e.g. inside a code
/// block).
List<MarkupSpan> nodeMarkup(TextNode node, LineKind kind) => switch (node) {
  TaskNode() || ListItemNode() => itemTextMarkup(node.text.toPlainText()),
  _ => lineMarkup(node.text.toPlainText(), kind),
};
