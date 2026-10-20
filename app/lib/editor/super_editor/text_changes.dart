import 'dart:math';

import 'package:collection/collection.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

/// One text edit the editor made, as views see it: the text from [from]
/// to [to] replaced by [text], the views [removed] between them gone.
typedef TextChange = ({
  ViewPlace from,
  ViewPlace to,
  String text,
  List<EditView> removed,
});

/// What the editor did to the text of [views], by node id in display
/// order, now that [document] shows it; `null` if nothing. Any edit the
/// library makes counts, also one across nodes (deleting a selection) or
/// one that adds nodes: the text of the nodes from the first to the last
/// one it touched is compared with the text they showed, with a line
/// break between nodes, and what differs is the change.
TextChange? textChangeOf(Document document, Map<String, EditView> views) {
  final ids = views.keys.toList();
  final rows = _rowsOf(document, views);
  final touched = {
    for (final (index, id) in ids.indexed)
      if (_textOf(document.getNodeById(id), views[id]!) != views[id]!.text)
        index,
    for (final row in rows)
      if (!views.containsKey(row.id)) row.anchor,
  };
  if (touched.isEmpty) return null;
  final first = touched.reduce(min);
  final last = touched.reduce(max);
  final shown = [for (final id in ids.sublist(first, last + 1)) views[id]!];
  final before = shown.map((view) => view.text).join('\n');
  final after = [
    for (final row in rows)
      if (row.anchor >= first && row.anchor <= last) row.text,
  ].join('\n');
  final head = _sameCount(before.codeUnits, after.codeUnits);
  final tail = _sameCount(
    before.substring(head).codeUnits.reversed,
    after.substring(head).codeUnits.reversed,
  );
  final from = _placeAt(shown, head);
  final to = _placeAt(shown, before.length - tail);
  return (
    from: (view: shown[from.index], offset: from.offset),
    to: (view: shown[to.index], offset: to.offset),
    text: after.substring(head, after.length - tail),
    removed: shown.sublist(from.index + 1, max(from.index + 1, to.index)),
  );
}

/// A text node of [document] in display order: its [text], and the index
/// of the view it shows, or for a node no view shows (one the library
/// added), of the view shown before it (or after it, at the top).
typedef _Row = ({String id, String text, int anchor});

List<_Row> _rowsOf(Document document, Map<String, EditView> views) {
  final ids = views.keys.toList();
  final rows = <_Row>[];
  for (final node in document) {
    final index = ids.indexOf(node.id);
    if (index >= 0) {
      rows.add((
        id: node.id,
        text: _textOf(node, views[node.id]!)!,
        anchor: index,
      ));
    } else if (node is TextNode) {
      rows.add((
        id: node.id,
        text: node.text.toPlainText(),
        anchor: rows.lastOrNull?.anchor ?? 0,
      ));
    }
  }
  return rows;
}

/// The text [node] shows of [view]: a text node's own text, a node that
/// shows the view drawn (a table) its text; `null` once it is gone.
String? _textOf(DocumentNode? node, EditView view) => switch (node) {
  null => null,
  TextNode(:final text) => text.toPlainText(),
  _ => view.text,
};

/// Where [offset] in the texts of [views], joined by line breaks, is: the
/// index of the view and the offset in it; right before a line break
/// between two views, the end of the one before it.
({int index, int offset}) _placeAt(List<EditView> views, int offset) {
  final starts = views.take(views.length - 1).fold([
    0,
  ], (starts, view) => [...starts, starts.last + view.text.length + 1]);
  final index = starts.lastIndexWhere((start) => start <= offset);
  return (index: index, offset: offset - starts[index]);
}

/// How many items [a] and [b] have equal at their start.
int _sameCount(Iterable<int> a, Iterable<int> b) =>
    IterableZip([a, b]).takeWhile((pair) => pair[0] == pair[1]).length;
