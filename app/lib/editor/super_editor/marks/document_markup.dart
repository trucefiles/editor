import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

/// The markup of each text node of [document], by node id: a list item's
/// text after its marker, a paragraph's whole line as of the [kindOf] its
/// line (e.g. a line inside a code block).
Map<String, List<MarkupSpan>> documentMarkup(
  Document document,
  LineKind Function(String nodeId) kindOf,
) => {
  for (final node in document)
    if (node is TextNode)
      node.id: switch (node) {
        TaskNode() || ListItemNode() => itemTextMarkup(node.text.toPlainText()),
        _ => lineMarkup(node.text.toPlainText(), kindOf(node.id)),
      },
};
