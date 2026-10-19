import 'package:super_editor/super_editor.dart';

/// Enter at the start of a list item with text adds an empty item of its
/// kind above it, as a text editor adds an empty line, and the caret
/// stays: the item keeps its text and its box. The library would split
/// it, leaving the box with the empty part.
EditCommand? enterAtItemStart(Editor editor, EditRequest request) {
  if (request is! InsertNewlineAtCaretRequest) return null;
  final selection = editor.composer.selection;
  if (selection == null || !selection.isCollapsed) return null;
  final caret = selection.extent;
  if (caret.nodePosition case TextNodePosition(offset: 0)) {
    final node = editor.document.getNodeById(caret.nodeId);
    if (_emptyItemLike(node, request.newNodeId) case final empty?) {
      return InsertNodeBeforeNodeCommand(
        existingNodeId: caret.nodeId,
        newNode: empty,
      );
    }
  }
  return null;
}

/// An empty, unchecked item [id] of [node]'s kind and indent, if [node] is
/// an item with text.
DocumentNode? _emptyItemLike(DocumentNode? node, String id) => switch (node) {
  TaskNode(:final text, :final indent) when text.isNotEmpty => TaskNode(
    id: id,
    text: AttributedText(),
    isComplete: false,
    indent: indent,
  ),
  ListItemNode(:final text, :final type, :final indent) when text.isNotEmpty =>
    ListItemNode(
      id: id,
      itemType: type,
      text: AttributedText(),
      indent: indent,
    ),
  _ => null,
};
