import 'package:super_editor/super_editor.dart';

import '../row_looks.dart';
import 'library_nodes.dart';

/// One node the library's document should hold: its id and look.
typedef TargetNode = ({String id, RowLook look});

/// Makes the library's document show [nodes], in order, and puts the
/// selection at [selection]: removes the nodes not among them, moves the
/// ones out of place, replaces those whose look changed, inserts the new
/// ones; nodes whose look is the same stay as they are. Edits the
/// document directly, so the library's own requests (which Visual edit
/// refuses) are never needed. A composing region on a node that goes or
/// changes its text is cleared.
final class PatchCommand extends EditCommand {
  PatchCommand(this.nodes, {required this.selection});

  final List<TargetNode> nodes;
  final DocumentSelection? selection;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.nonHistorical;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);
    final wanted = {for (final node in nodes) node.id: node.look};
    final removed = {
      for (final node in document)
        if (!wanted.containsKey(node.id)) node.id,
    };
    final retexted = {
      for (final node in document)
        if (wanted[node.id] case final look?
            when look != lookOf(node) &&
                _textOf(node) != _textOf(libraryNodeOf(node.id, look)))
          node.id,
    };
    if (_touches(composer.composingRegion.value, {...removed, ...retexted})) {
      executor.executeCommand(ChangeComposingRegionCommand(null));
    }
    if (_selects(composer.selection, removed)) {
      executor.executeCommand(
        const ChangeSelectionCommand(
          null,
          SelectionChangeType.clearSelection,
          SelectionReason.contentChange,
        ),
      );
    }
    for (final id in removed) {
      executor.executeCommand(DeleteNodeCommand(nodeId: id));
    }
    for (final (index, (:id, :look)) in nodes.indexed) {
      final current = document.getNodeById(id);
      if (current == null) {
        executor.executeCommand(
          InsertNodeAtIndexCommand(
            nodeIndex: index,
            newNode: libraryNodeOf(id, look),
          ),
        );
        continue;
      }
      if (document.getNodeIndexById(id) != index) {
        executor.executeCommand(MoveNodeCommand(nodeId: id, newIndex: index));
      }
      if (lookOf(current) != look) {
        executor.executeCommand(
          ReplaceNodeCommand(
            existingNodeId: id,
            newNode: libraryNodeOf(id, look),
          ),
        );
      }
    }
    if (selection != composer.selection) {
      executor.executeCommand(
        ChangeSelectionCommand(
          selection,
          SelectionChangeType.placeCaret,
          SelectionReason.contentChange,
        ),
      );
    }
  }

  static String? _textOf(DocumentNode node) =>
      node is TextNode ? node.text.toPlainText() : null;

  static bool _touches(DocumentRange? region, Set<String> nodes) =>
      region != null &&
      (nodes.contains(region.start.nodeId) ||
          nodes.contains(region.end.nodeId));

  static bool _selects(DocumentSelection? selection, Set<String> nodes) =>
      selection != null &&
      (nodes.contains(selection.base.nodeId) ||
          nodes.contains(selection.extent.nodeId));
}
