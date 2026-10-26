import 'package:super_editor/super_editor.dart';

/// One node the library's document should hold: its [id], whether a
/// node [shows] what it should, and how to [build] one that does.
typedef TargetNode = ({
  String id,
  bool Function(DocumentNode node) shows,
  DocumentNode Function() build,
});

/// Makes the library's document hold [nodes], in order, and puts the
/// selection at [selection]: removes the nodes not among them, moves the
/// ones out of place, replaces those that don't show what they should,
/// inserts the new ones; the others stay as they are. Edits the document
/// directly, so the library's own requests are never needed. A composing
/// region on a node that goes or changes its text is cleared.
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
    final wanted = {for (final node in nodes) node.id};
    final removed = {
      for (final node in document)
        if (!wanted.contains(node.id)) node.id,
    };
    final replacements = {
      for (final (:id, :shows, :build) in nodes)
        if (document.getNodeById(id) case final current? when !shows(current))
          id: build(),
    };
    final retexted = {
      for (final MapEntry(key: id, value: node) in replacements.entries)
        if (_textOf(document.getNodeById(id)!) != _textOf(node)) id,
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
    for (final (index, (:id, shows: _, :build)) in nodes.indexed) {
      if (document.getNodeById(id) == null) {
        executor.executeCommand(
          InsertNodeAtIndexCommand(nodeIndex: index, newNode: build()),
        );
        continue;
      }
      if (document.getNodeIndexById(id) != index) {
        executor.executeCommand(MoveNodeCommand(nodeId: id, newIndex: index));
      }
      if (replacements[id] case final node?) {
        executor.executeCommand(
          ReplaceNodeCommand(existingNodeId: id, newNode: node),
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
