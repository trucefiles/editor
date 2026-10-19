import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'display_nodes.dart';
import 'edit_nodes.dart';
import 'line_nodes.dart';

/// What one editor transaction did to the note's lines: [edits] for the
/// view model, and the ids of the nodes it added, in the order of the
/// added lines.
typedef TransactionEdits = ({List<BlockEdit> edits, List<String> added});

/// The [TransactionEdits] of the transaction that made [events] on
/// [document], whose line nodes [ids] knows. Only nodes the events touch
/// count: a touched line node still there changed, one gone was removed;
/// a node no line has is new and goes after the line shown above it.
/// Nodes that are no line (headings, buttons) are left out; removing a
/// drawn table or image removes its lines.
TransactionEdits transactionEdits(
  List<EditEvent> events,
  Document document,
  LineNodes ids,
) {
  final touched = <String>{};
  final removedNodes = <String, DocumentNode>{};
  for (final event in events) {
    if (event case DocumentEdit(change: final NodeDocumentChange change)) {
      touched.add(change.nodeId);
      if (change case NodeRemovedEvent(:final removedNode)) {
        removedNodes[change.nodeId] = removedNode;
      }
    }
  }
  if (touched.isEmpty) return (edits: const [], added: const []);
  final edits = <BlockEdit>[
    for (final id in touched)
      if (document.getNodeById(id) == null) ..._removed(id, removedNodes[id], ids),
  ];
  final added = <String>[];
  LineId? above;
  var run = <(String, Block)>[];
  void endRun() {
    if (run.isEmpty) return;
    edits.add(BlocksAdded([for (final (_, block) in run) block], after: above));
    added.addAll([for (final (id, _) in run) id]);
    run = [];
  }

  for (final node in document) {
    switch (node) {
      case DrawnTableNode(:final lines):
        endRun();
        above = lines.last.id;
      case DrawnImageNode(:final line):
        endRun();
        above = line.id;
      case DisplayNode():
        break;
      default:
        final line = ids.lineOf(node.id);
        final block = blockOf(node);
        if (line == null) {
          if (block != null) run.add((node.id, block));
          continue;
        }
        endRun();
        above = line;
        if (touched.contains(node.id) && block != null) {
          edits.add(BlockChanged(line, block));
        }
    }
  }
  endRun();
  return (edits: edits, added: added);
}

/// The edits for node [id], which is gone; it was [node] if known.
List<BlockEdit> _removed(String id, DocumentNode? node, LineNodes ids) =>
    switch ((ids.lineOf(id), node)) {
      (final line?, _) => [BlockRemoved(line)],
      (_, DrawnTableNode(:final lines)) => [
        for (final line in lines) BlockRemoved(line.id),
      ],
      (_, DrawnImageNode(:final line)) => [BlockRemoved(line.id)],
      _ => const [],
    };
