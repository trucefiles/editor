import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../write/draft.dart';
import '../commit.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';
import 'lifted_items.dart';
import 'outline.dart';
import 'text_commands.dart';

/// The frames the toolbar and shortcuts set.
enum FrameKind { checkbox, bullet, numbered, quote }

/// [kind] set on what [selection] covers, or taken off where all of it
/// has it already. A box is per item; bullet or numbered is per list,
/// the whole list changing kind; text not in a list becomes items of a
/// new list (joining a list of that kind right before or after it); a
/// quote wraps the blocks, in a list the items' text.
Edit setFrame(ShownNote note, TextSelection selection, FrameKind kind) {
  final rows = _selectedRows(note, selection);
  final fresh = note.tree.freshBlockIds.iterator;
  final (:replaced, :moved) = switch (kind) {
    FrameKind.quote => (replaced: _quote(note, rows, fresh), moved: _none),
    FrameKind.checkbox => (replaced: _boxes(note, rows, fresh), moved: _none),
    FrameKind.bullet => _listKind(note, rows, ListKind.bullet, fresh),
    FrameKind.numbered => _listKind(note, rows, ListKind.numbered, fresh),
  };
  return Edit(replaced: replaced, selection: selection.movedBy(moved));
}

/// The text rows [selection] covers, in order.
List<TextRow> _selectedRows(ShownNote note, TextSelection selection) {
  final (start, end) = ordered(note, selection);
  return note.rows
      .sublist(note.rowOf(start.slot)!, note.rowOf(end.slot)! + 1)
      .whereType<TextRow>()
      .toList();
}

/// The item [row] is the text of; `null` if it is none's.
ItemBlock? _itemOf(Row row) => switch (row.path.lastOrNull) {
  final ItemBlock item => item,
  _ => null,
};

/// The leaf [row] shows; `null` for an item's place or a gap.
LeafBlock? _leafOf(ShownNote note, TextRow row) => switch (row.slot) {
  LeafSlot(:final leaf) => note.tree.blockOf(leaf) as LeafBlock?,
  _ => null,
};

/// The leaves of [rows] in no item: text that becomes items.
List<LeafBlock> _freeLeaves(ShownNote note, List<TextRow> rows) => [
  for (final row in rows)
    if (_itemOf(row) == null) ?_leafOf(note, row),
];

List<ItemBlock> _items(List<TextRow> rows) =>
    {for (final row in rows) ?_itemOf(row)}.toList();

Map<BlockId, List<Draft>> _boxes(
  ShownNote note,
  List<TextRow> rows,
  Iterator<BlockId> fresh,
) {
  final items = _items(rows);
  final free = _freeLeaves(note, rows);
  final off = free.isEmpty && items.every((item) => item.hasBox);
  return {
    for (final item in items)
      if (off || !item.hasBox)
        item.id: [
          ItemDraft(
            item.id,
            kept(item.children),
            checked: off ? null : false,
            from: item,
          ),
        ],
    ..._newLists(note, free, ListKind.bullet, fresh, checked: false),
  };
}

const _none = <Slot, Slot>{};

/// What [_listKind] changes: the blocks [replaced], and the text places
/// [moved] where lifted items' places became paragraphs.
typedef _KindChange = ({
  Map<BlockId, List<Draft>> replaced,
  Map<Slot, Slot> moved,
});

_KindChange _listKind(
  ShownNote note,
  List<TextRow> rows,
  ListKind kind,
  Iterator<BlockId> fresh,
) {
  final items = _items(rows);
  final free = _freeLeaves(note, rows);
  final lists = {
    for (final item in items) note.tree.parentOf(item)! as ListBlock,
  };
  if (free.isEmpty && lists.every((list) => list.kind == kind)) {
    final lifted = {for (final item in items) item.id};
    final changes = {
      for (final list in lists) list.id: liftedOut(list, lifted, fresh),
    };
    return (
      replaced: {
        for (final MapEntry(:key, :value) in changes.entries) key: value.drafts,
      },
      moved: {for (final change in changes.values) ...change.moved},
    );
  }
  final replaced = {
    for (final list in lists)
      if (list.kind != kind)
        list.id: [
          ListDraft(
            list.id,
            kept(list.items),
            kind: kind,
            loose: list.loose,
            from: list,
          ),
        ],
    ..._newLists(note, free, kind, fresh),
  };
  return (replaced: replaced, moved: _none);
}

/// [leaves] as items of new lists of [kind], one per run of neighbors in
/// a container, each joining a list of that kind right before or after
/// it (a list may take runs on both sides); the items' boxes [checked]
/// if given.
Map<BlockId, List<Draft>> _newLists(
  ShownNote note,
  List<LeafBlock> leaves,
  ListKind kind,
  Iterator<BlockId> fresh, {
  bool? checked,
}) {
  final tree = note.tree;
  final runs = leaves
      .splitBetween(
        (a, b) =>
            tree.parentOf(a) != tree.parentOf(b) ||
            blockBefore(tree.parentOf(b)!, b)?.id != a.id,
      )
      .map((run) => _runOf(note, run, kind, fresh, checked: checked))
      .toList();
  final joined = groupBy(
    runs.where((run) => run.joins != null),
    (run) => run.joins!,
  );
  return {
    for (final run in runs) ...{
      for (final leaf in run.leaves) leaf.id: const [],
      if (run.joins == null)
        run.leaves.first.id: [
          ListDraft(
            (fresh..moveNext()).current,
            run.items,
            kind: kind,
            loose: false,
          ),
        ],
    },
    for (final MapEntry(key: list, value: runs) in joined.entries)
      list.id: [
        ListDraft.of(list, [
          for (final run in runs)
            if (run.first) ...run.items,
          ...kept(list.items),
          for (final run in runs)
            if (!run.first) ...run.items,
        ]),
      ],
  };
}

/// A run of neighbor [leaves] becoming [items]: of the list of their
/// kind it [joins], [first] if right before it; `null` for a new list.
typedef _Run = ({
  List<LeafBlock> leaves,
  List<ItemDraft> items,
  ListBlock? joins,
  bool first,
});

_Run _runOf(
  ShownNote note,
  List<LeafBlock> leaves,
  ListKind kind,
  Iterator<BlockId> fresh, {
  required bool? checked,
}) {
  final children = note.tree.parentOf(leaves.first)!.children;
  final index = children.indexOf(leaves.first);
  final (joins, first) = switch ((
    index > 0 ? children[index - 1] : null,
    children.elementAtOrNull(index + leaves.length),
  )) {
    (final ListBlock list, _) when list.kind == kind => (list, false),
    (_, final ListBlock list) when list.kind == kind => (list, true),
    _ => (null, false),
  };
  return (
    leaves: leaves,
    items: [
      for (final leaf in leaves)
        ItemDraft((fresh..moveNext()).current, [
          KeptDraft(leaf),
        ], checked: checked),
    ],
    joins: joins,
    first: first,
  );
}

Map<BlockId, List<Draft>> _quote(
  ShownNote note,
  List<TextRow> rows,
  Iterator<BlockId> fresh,
) {
  final tree = note.tree;
  final quoted = rows.where(
    (row) =>
        row.path.whereNot((block) => block is ListBlock).lastOrNull
            is QuoteBlock,
  );
  if (rows.isNotEmpty && quoted.length == rows.length) {
    // Each row's block goes one level out of its innermost quote.
    final byQuote = groupBy(
      rows,
      (row) => row.path.lastWhere((block) => block is QuoteBlock) as QuoteBlock,
    );
    return {
      for (final MapEntry(key: quote, value: rows) in byQuote.entries)
        quote.id: _outOf(quote, {
          for (final row in rows) ?_childOn(note, quote, row),
        }, fresh),
    };
  }
  final items = _items(rows);
  final free = _freeLeaves(note, rows);
  final runs = free.splitBetween(
    (a, b) =>
        tree.parentOf(a) != tree.parentOf(b) ||
        blockBefore(tree.parentOf(b)!, b)?.id != a.id,
  );
  return {
    for (final item in items)
      item.id: [
        ItemDraft.of(item, [
          QuoteDraft(
            (fresh..moveNext()).current,
            kept(item.children.takeWhile((child) => child is! ListBlock)),
          ),
          ...kept(item.children.skipWhile((child) => child is! ListBlock)),
        ]),
      ],
    for (final run in runs) ...{
      run.first.id: [QuoteDraft((fresh..moveNext()).current, kept(run))],
      for (final leaf in run.skip(1)) leaf.id: const [],
    },
  };
}

/// [quote]'s blocks with the [lifted] ones out of it, between the parts
/// of the quote around them; the first part keeps the quote's id.
List<Draft> _outOf(
  QuoteBlock quote,
  Set<BlockId> lifted,
  Iterator<BlockId> fresh,
) {
  final runs = quote.children
      .splitBetween((a, b) => lifted.contains(a.id) || lifted.contains(b.id))
      .toList();
  final keeping = runs.indexWhere((run) => !lifted.contains(run.first.id));
  return [
    for (final (index, run) in runs.indexed)
      if (lifted.contains(run.first.id))
        ...kept(run)
      else if (index == keeping)
        QuoteDraft.of(quote, kept(run))
      else
        QuoteDraft((fresh..moveNext()).current, kept(run)),
  ];
}

/// The child of [quote] that [row] shows in; `null` for a gap.
BlockId? _childOn(ShownNote note, QuoteBlock quote, TextRow row) =>
    row.path.skipWhile((block) => block != quote).skip(1).firstOrNull?.id ??
    _leafOf(note, row)?.id;
