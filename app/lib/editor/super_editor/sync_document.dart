import 'package:super_editor/super_editor.dart';

/// Makes [editor]'s document show [nodes], in order, in one transaction:
/// removes the nodes not among them, moves and replaces the ones that
/// differ, inserts the new ones, and leaves equal nodes untouched, so the
/// caret on them stays. A selection on a removed node is cleared; a
/// [selection] given is made the editor's in the same transaction.
void syncDocument(
  Editor editor,
  List<DocumentNode> nodes, {
  DocumentSelection? selection,
}) {
  final document = editor.document;
  final wanted = {for (final node in nodes) node.id};
  final current = [for (final node in document) node.id];
  final requests = <EditRequest>[
    if (_selectsAny(
      editor.composer.selection,
      current.toSet().difference(wanted),
    ))
      const ClearSelectionRequest(),
    for (final id in current)
      if (!wanted.contains(id)) DeleteNodeRequest(nodeId: id),
  ];
  final order = [
    for (final id in current)
      if (wanted.contains(id)) id,
  ];
  for (final (index, node) in nodes.indexed) {
    final at = order.indexOf(node.id);
    if (at < 0) {
      requests.add(InsertNodeAtIndexRequest(nodeIndex: index, newNode: node));
      order.insert(index, node.id);
      continue;
    }
    if (at != index) {
      requests.add(MoveNodeRequest(nodeId: node.id, newIndex: index));
      order
        ..removeAt(at)
        ..insert(index, node.id);
    }
    if (document.getNodeById(node.id) != node) {
      requests.add(ReplaceNodeRequest(existingNodeId: node.id, newNode: node));
    }
  }
  if (selection != null && selection != editor.composer.selection) {
    requests.add(
      ChangeSelectionRequest(
        selection,
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    );
  }
  if (requests.isNotEmpty) editor.execute(requests);
}

bool _selectsAny(DocumentSelection? selection, Set<String> nodes) =>
    selection != null &&
    (nodes.contains(selection.base.nodeId) ||
        nodes.contains(selection.extent.nodeId));
