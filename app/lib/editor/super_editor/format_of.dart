import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../text_format.dart';
import 'note_nodes.dart';

/// [format] applied to [selection] in [document], as Markdown marks in
/// the node's text: the node and its text with the selection after it.
/// A [TextFormat.link] goes to [url]. `null` without a selection, for a
/// selection across nodes, in text without inline formatting (code, a
/// table being edited; as the view of a node tells, see [viewOf]), or a
/// heading in a list item or quote.
({String nodeId, FormattedText formatted})? formatOf(
  Document document,
  TextFormat format, {
  required DocumentSelection? selection,
  required EditView? Function(String nodeId) viewOf,
  String url = '',
}) {
  final view = selection == null ? null : viewOf(selection.extent.nodeId);
  if (selection == null ||
      view == null ||
      selection.base.nodeId != selection.extent.nodeId ||
      !view.kind.hasInlines) {
    return null;
  }
  final node = document.getNodeById(selection.extent.nodeId);
  final (base, extent) = (
    selection.base.nodePosition,
    selection.extent.nodePosition,
  );
  if (node is! TextNode ||
      base is! TextNodePosition ||
      extent is! TextNodePosition) {
    return null;
  }
  final text = node.text.toPlainText();
  final (start, end) = base.offset <= extent.offset
      ? (base.offset, extent.offset)
      : (extent.offset, base.offset);
  final formatted = switch (format) {
    TextFormat.bold => toggleWrap(text, start, end, '**'),
    TextFormat.italic => toggleWrap(text, start, end, '*'),
    TextFormat.link => insertLink(text, start, end, url),
    TextFormat.heading when framesOf(view).isEmpty => cycleHeading(
      text,
      start,
      end,
    ),
    TextFormat.heading => null,
  };
  return formatted == null ? null : (nodeId: node.id, formatted: formatted);
}
