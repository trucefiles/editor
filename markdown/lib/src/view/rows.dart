import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../visible/visible_text.dart';

/// How Visual edit shows checked items in Done sections: those at a list's
/// top level after its open ones, unless the list's section is
/// [collapsed]. A view; the document's order stays.
final class DoneSections {
  DoneSections({Set<NodeId> collapsed = const {}})
    : collapsed = Set.unmodifiable(collapsed);

  /// Lists whose Done section is collapsed: its items do not show.
  final Set<NodeId> collapsed;

  /// These sections with [list]'s [collapsed] or open.
  DoneSections withCollapsed(NodeId list, {required bool collapsed}) =>
      DoneSections(
        collapsed: collapsed
            ? {...this.collapsed, list}
            : this.collapsed.difference({list}),
      );
}

/// One row of what Visual edit shows: a leaf, in the order it shows.
sealed class Row {
  const Row({required this.done});

  DocLeaf get leaf;

  /// Whether it shows in a Done section.
  final bool done;
}

/// A row that shows text and takes the caret: a paragraph, heading or
/// code block.
final class TextRow extends Row {
  const TextRow(this.leaf, {required super.done});

  @override
  final DocLeaf leaf;
}

/// A block without text, shown as a whole: a divider, table, HTML block,
/// link definitions or front matter.
final class BlockRow extends Row {
  const BlockRow(this.leaf, {required super.done});

  @override
  final DocLeaf leaf;
}

/// What Visual edit shows of [doc]: its rows, checked items in [done]
/// sections if given. Rows of a node are derived once per node object and
/// way of showing, so a change derives anew only the rows of the nodes it
/// rebuilt. Questions are lookups, derived once when first asked.
final class ViewRows {
  ViewRows(this.doc, {this.done});

  final DocTree doc;
  final DoneSections? done;

  /// The rows, in the order they show.
  late final List<Row> rows = _Rows(done)
      .of(doc.root, (top: true, inDone: false));

  late final Map<NodeId, int> _indexes = {
    for (final (index, row) in rows.indexed) row.leaf.id: index,
  };

  /// The index of the row [leaf] shows in; `null` if it shows in none.
  int? rowOf(NodeId leaf) => _indexes[leaf];

  /// The row [leaf] shows in; `null` if none.
  Row? row(NodeId leaf) => switch (_indexes[leaf]) {
    final index? => rows[index],
    null => null,
  };
}

/// What text place [leaf] shows: a text node's text, code as plain text.
VisibleText textOf(DocLeaf leaf) => switch (leaf) {
  TextNode(:final text) => text,
  CodeNode(:final code) =>
    code.isEmpty ? VisibleText.empty : VisibleText([TextPiece(code)]),
  _ => throw ArgumentError.value(leaf, 'leaf', 'no text place'),
};

/// Whether [leaf] is a text place: text or code.
bool isTextPlace(DocLeaf leaf) => leaf is TextNode || leaf is CodeNode;

/// Where in the tree rows are derived: at a list's [top] level (in no
/// item), and whether in a Done section.
typedef _Context = ({bool top, bool inDone});

/// The rows of a node, as derived last, with how they were derived.
typedef _Cached = ({_Context context, DoneSections? done, List<Row> rows});

final _cache = Expando<_Cached>('rows');

final class _Rows {
  _Rows(this._done);

  final DoneSections? _done;

  List<Row> of(DocBlock node, _Context context) {
    final cached = _cache[node];
    if (cached != null &&
        cached.context == context &&
        identical(cached.done, _done)) {
      return cached.rows;
    }
    final rows = List<Row>.unmodifiable(_derive(node, context));
    _cache[node] = (context: context, done: _done, rows: rows);
    return rows;
  }

  Iterable<Row> _derive(DocBlock node, _Context context) => switch (node) {
    DocLeaf() when isTextPlace(node) => [TextRow(node, done: context.inDone)],
    DocLeaf() => [BlockRow(node, done: context.inDone)],
    ListNode() => _list(node, context),
    ItemNode(:final children) => children.expand(
      (child) => of(child, (top: false, inDone: context.inDone)),
    ),
    DocContainer(:final children) => children.expand(
      (child) => of(child, context),
    ),
  };

  /// [list]'s rows: in Done sections at a list's top level, its open
  /// items first, then its checked ones unless collapsed.
  Iterable<Row> _list(ListNode list, _Context context) {
    final done = _done;
    if (done == null || !context.top) {
      return list.items.expand((item) => of(item, context));
    }
    bool isChecked(ItemNode item) => item.checked ?? false;
    return [
      for (final item in list.items)
        if (!isChecked(item)) ...of(item, (top: true, inDone: false)),
      if (!done.collapsed.contains(list.id))
        for (final item in list.items)
          if (isChecked(item)) ...of(item, (top: true, inDone: true)),
    ];
  }
}
