/// The frame buttons and shortcuts: boxes, bullet and numbered lists,
/// quotes.
library;

import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../tree/blocks.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';
import 'lifted_items.dart';
import 'text_commands.dart';

/// The frames the toolbar and shortcuts set.
enum FrameKind { checkbox, bullet, numbered, quote }

/// One change of a frame, on the tree as earlier changes left it.
typedef _Step = DocTree Function(DocTree doc, FreshIds fresh);

/// [kind] set on what [selection] covers, or taken off where all of it
/// has it already (a box or list taken off makes the items text). A box
/// is per item; bullet or numbered is per list, the whole list changing
/// kind; text not in a list becomes items of a new list (joining a list
/// of that kind right before or after it); a quote wraps the blocks, in
/// a list the items' text. The selection stays.
Change setFrame(ViewRows view, TextSelection selection, FrameKind kind) {
  final rows = _selectedRows(view, selection);
  final steps = switch (kind) {
    FrameKind.quote => _quote(view, rows),
    FrameKind.checkbox => _boxes(view, rows),
    FrameKind.bullet => _listKind(view, rows, ListKind.bullet),
    FrameKind.numbered => _listKind(view, rows, ListKind.numbered),
  };
  final fresh = view.doc.freshIds;
  final doc = steps.fold(view.doc, (doc, step) => step(doc, fresh));
  return (doc: DocTree(doc.root, nextId: fresh.next), selection: selection);
}

/// The text rows [selection] covers, in order.
List<TextRow> _selectedRows(ViewRows view, TextSelection selection) {
  final (start, end) = ordered(view, selection);
  return view.rows
      .sublist(view.rowOf(start.leaf)!, view.rowOf(end.leaf)! + 1)
      .whereType<TextRow>()
      .toList();
}

/// The item [row] is the text of; `null` if it is none's.
ItemNode? _itemOf(DocTree doc, Row row) => switch (doc.parentOf(row.leaf.id)) {
  final ItemNode item => item,
  _ => null,
};

/// The leaves of [rows] in no item: text that becomes items.
List<DocLeaf> _freeLeaves(DocTree doc, List<TextRow> rows) => [
  for (final row in rows)
    if (_itemOf(doc, row) == null) row.leaf,
];

List<ItemNode> _items(DocTree doc, List<TextRow> rows) =>
    {for (final row in rows) ?_itemOf(doc, row)}.toList();

List<_Step> _boxes(ViewRows view, List<TextRow> rows) {
  final doc = view.doc;
  final items = _items(doc, rows);
  final free = _freeLeaves(doc, rows);
  if (free.isEmpty && items.every((item) => item.hasBox)) {
    return _liftedOut(doc, items);
  }
  return [
    for (final item in items)
      if (!item.hasBox)
        (doc, _) =>
            doc.withNode((doc.nodeOf(item.id)! as ItemNode).withBox(false)),
    ..._newLists(doc, free, ListKind.bullet, checked: false),
  ];
}

List<_Step> _listKind(ViewRows view, List<TextRow> rows, ListKind kind) {
  final doc = view.doc;
  final items = _items(doc, rows);
  final free = _freeLeaves(doc, rows);
  final lists = {for (final item in items) doc.parentOf(item.id)! as ListNode};
  if (free.isEmpty && lists.every((list) => list.kind == kind)) {
    return _liftedOut(doc, items);
  }
  return [
    for (final list in lists)
      if (list.kind != kind)
        (doc, _) =>
            doc.withNode((doc.nodeOf(list.id)! as ListNode).withKind(kind)),
    ..._newLists(doc, free, kind),
  ];
}

/// [items] taken out of their lists, as text.
List<_Step> _liftedOut(DocTree doc, List<ItemNode> items) {
  final lists = {for (final item in items) doc.parentOf(item.id)! as ListNode};
  final lifted = {for (final item in items) item.id};
  return [
    for (final list in lists)
      (doc, fresh) => doc.edited({
        list.id: liftedOut(doc.nodeOf(list.id)! as ListNode, lifted, fresh),
      }),
  ];
}

/// [leaves] as items of new lists of [kind], one per run of neighbors in
/// a container, each joining a list of that kind right before or after
/// it (a list may take runs on both sides); the items' boxes [checked]
/// if given.
List<_Step> _newLists(
  DocTree doc,
  List<DocLeaf> leaves,
  ListKind kind, {
  bool? checked,
}) => [
  for (final run in _runs(doc, leaves))
    (doc, fresh) {
      final ids = [for (final leaf in run) leaf.id];
      final children = doc.parentOf(ids.first)!.children;
      final index = children.indexWhere((child) => child.id == ids.first);
      final items = [
        for (final id in ids)
          ItemNode(fresh.take(), [doc.nodeOf(id)!], checked: checked),
      ];
      final gone = {for (final id in ids) id: const <DocBlock>[]};
      return switch ((
        index > 0 ? children[index - 1] : null,
        children.elementAtOrNull(index + ids.length),
      )) {
        (final ListNode list, _) when list.kind == kind => doc.edited({
          ...gone,
          list.id: [
            list.withChildren([...list.items, ...items]),
          ],
        }),
        (_, final ListNode list) when list.kind == kind => doc.edited({
          ...gone,
          list.id: [
            list.withChildren([...items, ...list.items]),
          ],
        }),
        _ => doc.edited({
          ...gone,
          ids.first: [ListNode(fresh.take(), items, kind: kind)],
        }),
      };
    },
];

/// [leaves] in runs of neighbors in one container.
List<List<DocLeaf>> _runs(DocTree doc, List<DocLeaf> leaves) =>
    leaves.splitBetween((a, b) {
      final place = doc.placeOf(b.id)!;
      return doc.parentOf(a.id) != place.parent ||
          place.index == 0 ||
          place.parent!.children[place.index - 1].id != a.id;
    }).toList();

List<_Step> _quote(ViewRows view, List<TextRow> rows) {
  final doc = view.doc;
  QuoteNode? innermostQuote(Row row) => switch (doc
      .pathOf(row.leaf.id)
      .whereNot((node) => node is ListNode)
      .lastOrNull) {
    final QuoteNode quote => quote,
    _ => null,
  };
  if (rows.isNotEmpty && rows.every((row) => innermostQuote(row) != null)) {
    // Each row's block goes one level out of its innermost quote.
    final byQuote = groupBy(rows, (row) => innermostQuote(row)!.id);
    return [
      for (final MapEntry(key: quote, value: rows) in byQuote.entries)
        (doc, fresh) => doc.edited({
          quote: _outOf(doc.nodeOf(quote)! as QuoteNode, {
            for (final row in rows) _childOn(doc, quote, row),
          }, fresh),
        }),
    ];
  }
  final free = _freeLeaves(doc, rows);
  return [
    for (final item in _items(doc, rows))
      (doc, fresh) {
        final children = (doc.nodeOf(item.id)! as ItemNode).children;
        final text = children.takeWhile((child) => child is! ListNode);
        return doc.withNode(
          (doc.nodeOf(item.id)! as ItemNode).withChildren([
            QuoteNode(fresh.take(), text.toList()),
            ...children.skip(text.length),
          ]),
        );
      },
    for (final run in _runs(doc, free))
      (doc, fresh) => doc.edited({
        run.first.id: [
          QuoteNode(fresh.take(), [
            for (final leaf in run) doc.nodeOf(leaf.id)!,
          ]),
        ],
        for (final leaf in run.skip(1)) leaf.id: const [],
      }),
  ];
}

/// [quote]'s blocks with the [lifted] ones out of it, between the parts
/// of the quote around them; the first part keeps the quote's id.
List<DocBlock> _outOf(QuoteNode quote, Set<NodeId> lifted, FreshIds fresh) {
  final runs = quote.children
      .splitBetween((a, b) => lifted.contains(a.id) || lifted.contains(b.id))
      .toList();
  final keeping = runs.indexWhere((run) => !lifted.contains(run.first.id));
  return [
    for (final (index, run) in runs.indexed)
      if (lifted.contains(run.first.id))
        ...run
      else if (index == keeping)
        quote.withChildren(run)
      else
        QuoteNode(fresh.take(), run),
  ];
}

/// The child of [quote] that [row] shows in.
NodeId _childOn(DocTree doc, NodeId quote, Row row) => [
  ...doc.pathOf(row.leaf.id),
  row.leaf,
].skipWhile((node) => node.id != quote).skip(1).first.id;
