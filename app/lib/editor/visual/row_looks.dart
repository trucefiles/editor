import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../add_item_place/add_item_place.dart';
import '../marker.dart';

export '../add_item_place/add_item_place.dart';
export '../marker.dart';

/// A block a row is in, outermost first.
sealed class Frame {
  const Frame();
}

/// A quote: a bar beside its rows.
final class QuoteFrame extends Frame {
  const QuoteFrame();

  @override
  bool operator ==(Object other) => other is QuoteFrame;

  @override
  int get hashCode => (QuoteFrame).hashCode;
}

/// A list item: its rows indented; its [marker] beside the row that
/// [starts] it. [subitems]: how many items are in it.
final class ItemFrame extends Frame {
  const ItemFrame(
    this.item, {
    required this.marker,
    required this.starts,
    required this.subitems,
  });

  final NodeId item;
  final Marker marker;
  final bool starts;
  final int subitems;

  bool get checked => marker == const BoxMarker(checked: true);

  @override
  bool operator ==(Object other) =>
      other is ItemFrame &&
      other.item == item &&
      other.marker == marker &&
      other.starts == starts &&
      other.subitems == subitems;

  @override
  int get hashCode => Object.hash(item, marker, starts, subitems);
}

/// How one node of what Visual edit shows looks: the one place that says
/// what shows where. Equal looks show the same.
sealed class RowLook {
  const RowLook();

  /// Names the node across changes: the leaf it shows, or what a node
  /// without one is for.
  Object? get key;
}

/// A row with text: a paragraph, heading or code block, inside [frames];
/// [done] if it shows in a Done section.
final class TextLook extends RowLook {
  const TextLook(this.leaf, {required this.frames, required this.done});

  final DocLeaf leaf;
  final List<Frame> frames;
  final bool done;

  @override
  NodeId get key => leaf.id;

  @override
  bool operator ==(Object other) =>
      other is TextLook &&
      identical(other.leaf, leaf) &&
      other.done == done &&
      _frames.equals(other.frames, frames);

  @override
  int get hashCode => Object.hash(leaf, done, _frames.hash(frames));
}

/// A block without text, shown whole: a divider, table, HTML block, link
/// definitions or front matter.
final class BlockLook extends RowLook {
  const BlockLook(this.leaf, {required this.frames, required this.done});

  final DocLeaf leaf;
  final List<Frame> frames;
  final bool done;

  @override
  NodeId get key => leaf.id;

  @override
  bool operator ==(Object other) =>
      other is BlockLook &&
      identical(other.leaf, leaf) &&
      other.done == done &&
      _frames.equals(other.frames, frames);

  @override
  int get hashCode => Object.hash(leaf, done, _frames.hash(frames));
}

/// A raw block open as its raw text. A node of its own, not the one
/// that shows the block whole: the library keeps a node's kind for its
/// id.
final class RawTextLook extends RowLook {
  const RawTextLook(this.raw, {required this.frames});

  final RawRegion raw;
  final List<Frame> frames;

  /// The key of the node that shows [block] open.
  static Object keyOf(NodeId block) => (open: block);

  @override
  Object get key => keyOf(raw.block);

  @override
  bool operator ==(Object other) =>
      other is RawTextLook &&
      other.raw.text == raw.text &&
      other.raw.block == raw.block &&
      _frames.equals(other.frames, frames);

  @override
  int get hashCode => Object.hash(raw.block, raw.text, _frames.hash(frames));
}

/// The heading of [list]'s Done section, over its [count] checked items.
final class DoneHeadingLook extends RowLook {
  const DoneHeadingLook(
    this.list, {
    required this.count,
    required this.collapsed,
  });

  final NodeId list;
  final int count;
  final bool collapsed;

  @override
  (Symbol, NodeId) get key => (#done, list);

  @override
  bool operator ==(Object other) =>
      other is DoneHeadingLook &&
      other.list == list &&
      other.count == count &&
      other.collapsed == collapsed;

  @override
  int get hashCode => Object.hash(list, count, collapsed);
}

/// The button that adds an item to [list]: as its [first] item, else its
/// last.
final class AddItemLook extends RowLook {
  const AddItemLook(this.list, {required this.first});

  final NodeId list;
  final bool first;

  @override
  (Symbol, NodeId) get key => (#add, list);

  @override
  bool operator ==(Object other) =>
      other is AddItemLook && other.list == list && other.first == first;

  @override
  int get hashCode => Object.hash(list, first);
}

const _frames = ListEquality<Frame>();

/// What Visual edit shows of [shown], in order. A box shows [showsChecked]
/// (a tap may be waiting); lists at the top level get an Add item button
/// at [addItems], and their Done heading when [shown] has Done sections;
/// the subitems of [folded] (an item being dragged) don't show.
@immutable
final class RowLooks {
  RowLooks(
    this.shown, {
    required this.showsChecked,
    required this.addItems,
    this.folded,
  });

  final FormattedContent shown;
  final bool Function(ItemNode item) showsChecked;
  final AddItemPlace? addItems;
  final NodeId? folded;

  DocTree get _doc => shown.view.doc;
  ViewRows get _view => shown.view;

  /// The looks, in the order they show.
  late final List<RowLook> looks = _of(_doc.root).toList();

  /// The rows of each list at the top level, in the order they show.
  late final Map<NodeId?, List<Row>> _rowsOfList = _view.rows.groupListsBy(
    (row) => _topList(row.leaf.id)?.id,
  );

  /// How many items each item holds, itself included: each item counts
  /// for itself and every item it is in.
  late final Map<NodeId, int> _itemsIn = nodesIn(_doc.root)
      .whereType<ItemNode>()
      .expand((item) => [item, ..._doc.pathOf(item.id).whereType<ItemNode>()])
      .groupFoldBy((item) => item.id, (int? count, _) => (count ?? 0) + 1);

  ListNode? _topList(NodeId leaf) =>
      _doc.pathOf(leaf).whereType<ListNode>().firstOrNull;

  Iterable<RowLook> _of(DocBlock node) => switch (node) {
    final ListNode list => _list(list),
    DocContainer(:final children) => children.expand(_of),
    final DocLeaf leaf => [?_row(leaf)],
  };

  Iterable<RowLook> _list(ListNode list) {
    final rows = (_rowsOfList[list.id] ?? const <Row>[])
        .where((row) => !_isFolded(row.leaf.id))
        .toList();
    final open = rows.where((row) => !row.done);
    final done = rows.where((row) => row.done);
    final sections = _view.done;
    final checked = list.items.where((item) => item.checked ?? false).length;
    return [
      if (addItems == AddItemPlace.top) AddItemLook(list.id, first: true),
      ...open.map(_look),
      if (addItems == AddItemPlace.bottom) AddItemLook(list.id, first: false),
      if (sections != null && checked > 0)
        DoneHeadingLook(
          list.id,
          count: checked,
          collapsed: sections.collapsed.contains(list.id),
        ),
      ...done.map(_look),
    ];
  }

  RowLook? _row(DocLeaf leaf) => switch (_view.row(leaf.id)) {
    final row? when !_isFolded(leaf.id) => _look(row),
    _ => null,
  };

  RowLook _look(Row row) {
    final frames = _framesOf(row.leaf.id);
    return switch (row) {
      _ when shown.raw?.block == row.leaf.id => RawTextLook(
        shown.raw!,
        frames: frames,
      ),
      TextRow(:final leaf) => TextLook(leaf, frames: frames, done: row.done),
      BlockRow(:final leaf) => BlockLook(leaf, frames: frames, done: row.done),
    };
  }

  /// Whether [leaf] is in a subitem of the [folded] item.
  bool _isFolded(NodeId leaf) {
    final folded = this.folded;
    if (folded == null) return false;
    final path = _doc.pathOf(leaf);
    final index = path.indexWhere((node) => node.id == folded);
    return index >= 0 && path.skip(index + 1).any((node) => node is ItemNode);
  }

  List<Frame> _framesOf(NodeId leaf) {
    final path = _doc.pathOf(leaf);
    return [
      for (final (index, node) in path.indexed)
        ...switch (node) {
          QuoteNode() => const [QuoteFrame()],
          final ItemNode item => [
            ItemFrame(
              item.id,
              marker: _markerOf(item, path[index - 1] as ListNode),
              starts: leavesIn(item).first.id == leaf,
              subitems: _itemsIn[item.id]! - 1,
            ),
          ],
          _ => const <Frame>[],
        },
    ];
  }

  Marker _markerOf(ItemNode item, ListNode list) => switch (item.checked) {
    bool() => BoxMarker(checked: showsChecked(item)),
    null => switch (list.numberAt(_doc.placeOf(item.id)!.index)) {
      final number? => NumberMarker(number),
      null => const BulletMarker(),
    },
  };
}
