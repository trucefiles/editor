import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../text_format.dart';

/// Applies [format] to [selection] in [editor], as Markdown marks in the
/// line's text; a [TextFormat.link] goes to [url]. Does nothing without a
/// selection, for a selection across lines, in a code block or table (as
/// the view of a node's line tells, see [viewOf]), or a heading on a list
/// item or quote.
void applyFormat(
  Editor editor,
  TextFormat format, {
  required DocumentSelection? selection,
  required LineView? Function(String nodeId) viewOf,
  String url = '',
}) {
  if (selection == null ||
      selection.base.nodeId != selection.extent.nodeId ||
      (viewOf(selection.extent.nodeId)?.kind ?? LineKind.plain) !=
          LineKind.plain) {
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
    TextFormat.heading when node is ParagraphNode => cycleHeading(
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
