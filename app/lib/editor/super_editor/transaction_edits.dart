import 'package:collection/collection.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'display_nodes.dart';
import 'line_nodes.dart';
import 'note_nodes.dart';

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
  final changes = [
    for (final event in events)
      if (event case DocumentEdit(change: final NodeDocumentChange change))
        change,
  ];
  if (changes.isEmpty) return (edits: const [], added: const []);
  final touched = {for (final change in changes) change.nodeId};
  final removed = {
    for (final change in changes)
      if (change case NodeRemovedEvent(:final removedNode))
        change.nodeId: removedNode,
  };
  final groups = [for (final node in document) ?_rowOf(node, ids, touched)]
      .splitBefore((row) => row is _LineRow)
      .toList();
  return (
    edits: [
      for (final id in touched)
        if (document.getNodeById(id) == null) ..._removed(id, removed[id], ids),
      for (final group in groups) ..._editsOf(group),
    ],
    added: [
      for (final group in groups)
        for (final row in group.whereType<_NewRow>()) row.nodeId,
    ],
  );
}

/// A node as the edits see it, if it counts: a line or a new node.
sealed class _Row {}

/// A node that shows a line: [changed] to its block if touched; a drawn
/// table or image counts as its last line, never changed.
final class _LineRow extends _Row {
  _LineRow(this.line, this.changed);

  final LineId line;
  final Block? changed;
}

/// A node no line has yet, showing [block].
final class _NewRow extends _Row {
  _NewRow(this.nodeId, this.block);

  final String nodeId;
  final Block block;
}

/// The row of [node], whose line nodes [ids] knows; `null` for a node
/// that is no line (headings, buttons) or shows no block.
_Row? _rowOf(DocumentNode node, LineNodes ids, Set<String> touched) =>
    switch (node) {
      DrawnTableNode(:final lines) => _LineRow(lines.last.id, null),
      DrawnImageNode(:final line) => _LineRow(line.id, null),
      DisplayNode() => null,
      _ => switch ((ids.lineOf(node.id), blockOf(node))) {
        (final line?, final block) => _LineRow(
          line,
          touched.contains(node.id) ? block : null,
        ),
        (null, final block?) => _NewRow(node.id, block),
        (null, null) => null,
      },
    };

/// The edits of a line and the new nodes right below it, or of the new
/// nodes at the top: its change, then the new lines after it.
List<BlockEdit> _editsOf(List<_Row> group) {
  final line = group.whereType<_LineRow>().firstOrNull;
  final added = [for (final row in group.whereType<_NewRow>()) row.block];
  return [
    if (line case _LineRow(:final line, changed: final block?))
      BlockChanged(line, block),
    if (added.isNotEmpty) BlocksAdded(added, after: line?.line),
  ];
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
