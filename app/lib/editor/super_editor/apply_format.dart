import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../text_format.dart';
import 'note_nodes.dart';

/// Applies [format] to [selection] in [editor], as Markdown marks in the
/// node's text; a [TextFormat.link] goes to [url]. Does nothing without a
/// selection, for a selection across nodes, in text without inline
/// formatting (code, a table being edited; as the view of a node tells,
/// see [viewOf]), or a heading in a list item or quote.
void applyFormat(
  Editor editor,
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
    return;
  }
  final node = editor.document.getNodeById(selection.extent.nodeId);
  final (base, extent) = (
    selection.base.nodePosition,
    selection.extent.nodePosition,
  );
  if (node is! TextNode ||
      base is! TextNodePosition ||
      extent is! TextNodePosition) {
    return;
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
  if (formatted == null) return;
  DocumentPosition at(int offset) => DocumentPosition(
    nodeId: node.id,
    nodePosition: TextNodePosition(offset: offset),
  );
  editor.execute([
    ReplaceNodeRequest(
      existingNodeId: node.id,
      newNode: node.copyTextNodeWith(text: AttributedText(formatted.text)),
    ),
    ChangeSelectionRequest(
      DocumentSelection(base: at(formatted.start), extent: at(formatted.end)),
      SelectionChangeType.alteredContent,
      SelectionReason.userInteraction,
    ),
  ]);
}
