import 'package:super_editor/super_editor.dart';

/// One node the library's document should hold: its [id], whether a
/// node [shows] what it should, and how to [build] one that does.
typedef TargetNode = ({
  String id,
  bool Function(DocumentNode node) shows,
  DocumentNode Function() build,
});

/// Makes the [count] nodes of the library's document from [start] the
/// [nodes] instead, in order, and puts the selection at [selection]:
/// removes the nodes there not among them, moves the ones out of place,
/// replaces those that don't show what they should, inserts the new ones;
/// the others stay as they are, and the nodes before and after the range
/// are never looked at. Edits the document directly, so the library's own
/// requests are never needed. A composing region on a node that goes or
/// changes its text is cleared. [byUser] says the change came from the
/// user's own input, so the view follows the caret (the library scrolls
/// to it); a text from elsewhere moves nothing.
final class PatchCommand extends EditCommand {
  PatchCommand(
    this.nodes, {
    required this.start,
    required this.count,
    required this.selection,
    required this.byUser,
  });

  final List<TargetNode> nodes;
  final int start;
  final int count;
  final DocumentSelection? selection;
  final bool byUser;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.nonHistorical;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);
    final range = {
      for (final offset in Iterable<int>.generate(count))
        document.getNodeAt(start + offset)!.id,
    };
    assert(
      nodes.every(
        (node) =>
            range.contains(node.id) || document.getNodeById(node.id) == null,
      ),
      'a node of the range is outside it',
    );
    final wanted = {for (final node in nodes) node.id};
    final removed = range.difference(wanted);
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
    for (final (offset, (:id, shows: _, :build)) in nodes.indexed) {
      final index = start + offset;
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
          byUser
              ? SelectionReason.userInteraction
              : SelectionReason.contentChange,
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
