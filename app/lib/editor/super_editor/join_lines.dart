import 'package:super_editor/super_editor.dart';

/// Joins lines as a text editor does, in one press: Backspace at the start
/// of a line joins it into the line above, Delete at the end of a line
/// joins the line below into it. Handles the requests both hardware keys
/// and soft keyboards end in. Without a line right next to it (at the top,
/// or by a heading or button), only an empty line goes away.
EditCommand? joinLines(Editor editor, EditRequest request) => switch (request) {
  DeleteUpstreamAtBeginningOfNodeRequest(:final TextNode node) =>
    JoinLinesCommand(
      upper: editor.document.getNodeBeforeById(node.id)?.id,
      lower: node.id,
      caretInLower: true,
    ),
  CombineParagraphsRequest(:final firstNodeId, :final secondNodeId) =>
    JoinLinesCommand(
      upper: firstNodeId,
      lower: secondNodeId,
      caretInLower: false,
    ),
  _ => null,
};

/// Joins the text node [lower] into [upper]. The caret is in [lower] for
/// Backspace, else in [upper] for Delete.
final class JoinLinesCommand extends EditCommand {
  JoinLinesCommand({
    required this.upper,
    required this.lower,
    required this.caretInLower,
  });

  final String? upper;
  final String lower;
  final bool caretInLower;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final upperNode = upper == null ? null : document.getNodeById(upper!);
    final lowerNode = document.getNodeById(lower);
    final adjacent =
        upperNode is TextNode &&
        lowerNode is TextNode &&
        document.getNodeAfterById(upperNode.id)?.id == lowerNode.id;
    if (!adjacent) {
      final caretNode = caretInLower ? lowerNode : upperNode;
      if (caretNode is TextNode && caretNode.text.isEmpty) {
        _drop(document, caretNode, executor);
      }
      return;
    }
    if (!caretInLower && upperNode.text.isEmpty) {
      // Keeps the line below as it is, e.g. checked.
      _placeCaret(executor, lowerNode.id, 0);
      executor.executeCommand(DeleteNodeCommand(nodeId: upperNode.id));
      return;
    }
    executor.executeCommand(
      ReplaceNodeCommand(
        existingNodeId: upperNode.id,
        newNode: upperNode.copyTextNodeWith(
          text: upperNode.text.copyAndAppend(lowerNode.text),
        ),
      ),
    );
    _placeCaret(executor, upperNode.id, upperNode.text.length);
    executor.executeCommand(DeleteNodeCommand(nodeId: lowerNode.id));
  }

  /// Removes the empty [node], unless it is the only line; the caret goes
  /// to the start of the next line, else the end of the line before.
  void _drop(Document document, TextNode node, CommandExecutor executor) {
    final next = _textNear(document, node, forward: true);
    final previous = _textNear(document, node, forward: false);
    final target = next ?? previous;
    if (target == null) return;
    _placeCaret(executor, target.id, next != null ? 0 : target.text.length);
    executor.executeCommand(DeleteNodeCommand(nodeId: node.id));
  }

  static TextNode? _textNear(
    Document document,
    DocumentNode node, {
    required bool forward,
  }) {
    for (
      var other = _step(document, node, forward: forward);
      other != null;
      other = _step(document, other, forward: forward)
    ) {
      if (other is TextNode) return other;
    }
    return null;
  }

  static DocumentNode? _step(
    Document document,
    DocumentNode node, {
    required bool forward,
  }) => forward
      ? document.getNodeAfterById(node.id)
      : document.getNodeBeforeById(node.id);

  static void _placeCaret(CommandExecutor executor, String nodeId, int offset) {
    executor
      ..executeCommand(
        ChangeSelectionCommand(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: TextNodePosition(offset: offset),
            ),
          ),
          SelectionChangeType.deleteContent,
          SelectionReason.userInteraction,
        ),
      )
      ..executeCommand(ChangeComposingRegionCommand(null));
  }
}
