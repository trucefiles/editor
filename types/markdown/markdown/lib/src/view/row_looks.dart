import 'package:collection/collection.dart';

import '../doc/doc_nodes.dart';
import 'add_item_place.dart';
import 'marker.dart';
import 'rows.dart';

/// A block a row is in, outermost first.
sealed class Frame {
  const Frame();
}

/// [quote]: a bar beside its rows; it [starts] at its first row as shown
/// and [ends] at its last.
final class QuoteFrame extends Frame {
  const QuoteFrame(this.quote, {required this.starts, required this.ends});

  final NodeId quote;
  final bool starts;
  final bool ends;

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other is QuoteFrame &&
          other.quote == quote &&
          other.starts == starts &&
          other.ends == ends;

  @override
  int get hashCode => Object.hash(quote, starts, ends);
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
      identical(other, this) ||
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
      identical(other, this) ||
      other is TextLook &&
          identical(other.leaf, leaf) &&
          other.done == done &&
          _frames.equals(other.frames, frames);

  @override
  int get hashCode => Object.hash(leaf, done, _frames.hash(frames));
}

/// A block without text, shown whole: a divider, table, HTML block, link
/// definitions or front matter.
/// [selected] while it is selected whole (not while the caret is right
/// after it).
final class BlockLook extends RowLook {
  const BlockLook(
    this.leaf, {
    required this.frames,
    required this.done,
    this.selected = false,
  });

  final DocLeaf leaf;
  final List<Frame> frames;
  final bool done;
  final bool selected;

  @override
  NodeId get key => leaf.id;

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other is BlockLook &&
          identical(other.leaf, leaf) &&
          other.done == done &&
          other.selected == selected &&
          _frames.equals(other.frames, frames);

  @override
  int get hashCode => Object.hash(leaf, done, selected, _frames.hash(frames));
}

/// A raw block open as its raw [text]. A node of its own, not the one
/// that shows the [block] whole: the library keeps a node's kind for its
/// id.
final class RawTextLook extends RowLook {
  const RawTextLook(this.block, this.text, {required this.frames});

  final NodeId block;
  final String text;
  final List<Frame> frames;

  /// The key of the node that shows [block] open.
  static Object keyOf(NodeId block) => (open: block);

  @override
  Object get key => keyOf(block);

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other is RawTextLook &&
          other.text == text &&
          other.block == block &&
          _frames.equals(other.frames, frames);

  @override
  int get hashCode => Object.hash(block, text, _frames.hash(frames));
}

/// The heading of [list]'s Done section, over its [count] checked items,
/// inside the list's [frames].
final class DoneHeadingLook extends RowLook {
  const DoneHeadingLook(
    this.list, {
    required this.count,
    required this.collapsed,
    required this.frames,
  });

  final NodeId list;
  final int count;
  final bool collapsed;
  final List<Frame> frames;

  @override
  (Symbol, NodeId) get key => (#done, list);

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other is DoneHeadingLook &&
          other.list == list &&
          other.count == count &&
          other.collapsed == collapsed &&
          _frames.equals(other.frames, frames);

  @override
  int get hashCode => Object.hash(list, count, collapsed, _frames.hash(frames));
}

/// The button that adds an item to [list]: as its [first] item, else its
/// last; inside the list's [frames].
final class AddItemLook extends RowLook {
  const AddItemLook(this.list, {required this.first, required this.frames});

  final NodeId list;
  final bool first;
  final List<Frame> frames;

  @override
  (Symbol, NodeId) get key => (#add, list);

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other is AddItemLook &&
          other.list == list &&
          other.first == first &&
          _frames.equals(other.frames, frames);

  @override
  int get hashCode => Object.hash(list, first, _frames.hash(frames));
}

const _frames = ListEquality<Frame>();

/// What Visual edit shows of [view], in order: the one place that says
/// what shows where. A block [selected] whole shows so, the [raw] block
/// open as its text; a box of an item in [waiting] (a tap waits) shows
/// flipped. Lists at the top level get an Add item button at [addItems],
/// and their Done heading when [view] has Done sections, both in the
/// quotes the list is in; the subitems of [folded] (an item being
/// dragged) don't show. A quote's bar runs from its first row as shown to
/// its last.
///
/// Looks are derived per node, top down, and a node's looks are reused
/// while it is the same object in the same surroundings (the frames
/// around it, its list number or box, whether in a Done section), so a
/// change derives anew only the looks of the nodes it rebuilt. What
/// changes without a tree change (the selected block, the open raw block,
/// waiting taps, the folded item) is derived anew along its path.
final class RowLooks {
  RowLooks(
    this.view, {
    this.selected,
    this.raw,
    this.waiting = const {},
    this.addItems,
    this.folded,
  });

  final ViewRows view;
  final NodeId? selected;
  final ({NodeId block, String text})? raw;
  final Set<NodeId> waiting;
  final AddItemPlace? addItems;
  final NodeId? folded;

  /// The looks, in the order they show.
  late final List<RowLook> looks = _of(view.doc.root, (
    frames: const [],
    top: true,
    done: false,
    folded: false,
    marker: null,
  ));

  /// The nodes whose looks are derived anew each time, never cached:
  /// those shown apart from the tree, and the containers they are in.
  late final Set<NodeId> _fresh = {
    for (final id in [?selected, ?raw?.block, ...waiting, ?folded]) ...[
      id,
      ...view.doc.pathOf(id).map((container) => container.id),
    ],
  };

  List<RowLook> _of(DocBlock node, _Context context) {
    if (_fresh.contains(node.id)) return _derive(node, context);
    final cached = _cache[node];
    if (cached != null &&
        cached.addItems == addItems &&
        identical(cached.sections, view.done) &&
        _sameContext(cached.context, context)) {
      return cached.looks;
    }
    final looks = _derive(node, context);
    _cache[node] = (
      context: context,
      addItems: addItems,
      sections: view.done,
      looks: looks,
    );
    return looks;
  }

  List<RowLook> _derive(DocBlock node, _Context context) =>
      List.unmodifiable(switch (node) {
        final DocLeaf leaf => [_leafLook(leaf, context)],
        ItemNode() when context.folded => const <RowLook>[],
        final ItemNode item => _joined(
          [
            ...context.frames,
            ItemFrame(
              item.id,
              marker: context.marker!,
              starts: true,
              subitems: nodesIn(item).whereType<ItemNode>().length - 1,
            ),
          ],
          [
            for (final child in item.children)
              _Child(
                child,
                top: false,
                done: context.done,
                folded: context.folded || item.id == folded,
              ),
          ],
        ),
        final ListNode list when context.top => _joined(
          context.frames,
          _topListParts(list, context),
        ),
        final ListNode list => _joined(context.frames, [
          for (final (index, item) in list.items.indexed)
            _Child(
              item,
              top: false,
              done: context.done,
              folded: context.folded,
              marker: _markerOf(item, list, index),
            ),
        ]),
        final QuoteNode quote => _joined(
          [...context.frames, QuoteFrame(quote.id, starts: true, ends: true)],
          [
            for (final child in quote.children)
              _Child(
                child,
                top: context.top,
                done: context.done,
                folded: context.folded,
              ),
          ],
        ),
        final DocContainer container => _joined(context.frames, [
          for (final child in container.children)
            _Child(
              child,
              top: context.top,
              done: context.done,
              folded: context.folded,
            ),
        ]),
      });

  RowLook _leafLook(DocLeaf leaf, _Context context) => switch (raw) {
    (:final block, :final text) when block == leaf.id => RawTextLook(
      block,
      text,
      frames: context.frames,
    ),
    _ when isTextPlace(leaf) => TextLook(
      leaf,
      frames: context.frames,
      done: context.done,
    ),
    _ => BlockLook(
      leaf,
      frames: context.frames,
      done: context.done,
      selected: selected == leaf.id,
    ),
  };

  /// What a list at the top level shows: its items in the order Done
  /// sections give, its Add item button, and its Done heading.
  List<_Part> _topListParts(ListNode list, _Context context) {
    final sections = view.done;
    final items = list.items;
    final checked = items.where((item) => item.checked ?? false).length;
    _Part item(int index, {required bool done}) => _Child(
      items[index],
      top: true,
      done: done,
      folded: false,
      marker: _markerOf(items[index], list, index),
    );
    final shown = switch (sections) {
      final sections? => sections.order(list),
      null => [
        for (final index in Iterable<int>.generate(items.length))
          (index: index, done: false),
      ],
    };
    return [
      if (addItems == AddItemPlace.top)
        _Own((frames) => AddItemLook(list.id, first: true, frames: frames)),
      for (final (:index, :done) in shown)
        if (!done) item(index, done: false),
      if (addItems == AddItemPlace.bottom)
        _Own((frames) => AddItemLook(list.id, first: false, frames: frames)),
      if (sections != null && checked > 0)
        _Own(
          (frames) => DoneHeadingLook(
            list.id,
            count: checked,
            collapsed: sections.collapsed.contains(list.id),
            frames: frames,
          ),
        ),
      for (final (:index, :done) in shown)
        if (done) item(index, done: true),
    ];
  }

  Marker _markerOf(ItemNode item, ListNode list, int index) =>
      switch (item.checked) {
        final bool checked => BoxMarker(
          checked: checked != waiting.contains(item.id),
        ),
        null => switch (list.numberAt(index)) {
          final number? => NumberMarker(number),
          null => const BulletMarker(),
        },
      };

  /// The looks of [parts] in order, inside [frames]: a quote's bar starts
  /// at the first part that shows and ends at the last; an item starts at
  /// its first part.
  List<RowLook> _joined(List<Frame> frames, List<_Part> parts) {
    final first = parts.indexWhere(_shows);
    final last = parts.lastIndexWhere(_shows);
    final inner = _placed(frames, first: false, last: false);
    return [
      for (final (index, part) in parts.indexed)
        ...switch ((part, index == first || index == last)) {
          (_, true) => _looksOf(
            part,
            _placed(frames, first: index == first, last: index == last),
          ),
          _ => _looksOf(part, inner),
        },
    ];
  }

  List<RowLook> _looksOf(_Part part, List<Frame> frames) => switch (part) {
    _Own(:final look) => [look(frames)],
    _Child(
      :final node,
      :final top,
      :final done,
      :final folded,
      :final marker,
    ) =>
      _of(node, (
        frames: frames,
        top: top,
        done: done,
        folded: folded,
        marker: marker,
      )),
  };

  /// Whether [part] shows a row: all but items inside the folded item.
  static bool _shows(_Part part) => switch (part) {
    _Own() => true,
    _Child(folded: false) => true,
    _Child(:final node) => _showsFolded(node),
  };

  /// Whether [node], inside the folded item, shows a row.
  static bool _showsFolded(DocBlock node) => switch (node) {
    ItemNode() || ListNode() => false,
    DocContainer(:final children) => children.any(_showsFolded),
    DocLeaf() => true,
  };

  /// [frames] as they hold for a part: a quote's bar starts only at its
  /// [first] part, ends only at its [last]; an item starts only at its
  /// first.
  static List<Frame> _placed(
    List<Frame> frames, {
    required bool first,
    required bool last,
  }) => [
    for (final frame in frames)
      switch (frame) {
        QuoteFrame(:final quote, :final starts, :final ends) => QuoteFrame(
          quote,
          starts: starts && first,
          ends: ends && last,
        ),
        ItemFrame(:final item, :final marker, :final starts, :final subitems) =>
          ItemFrame(
            item,
            marker: marker,
            starts: starts && first,
            subitems: subitems,
          ),
      },
  ];
}

/// Where in the tree looks are derived: the [frames] the node's rows get
/// (a quote's bar starting at its first row, ending at its last, an item
/// starting at its first, as far as the node holds them), whether at a
/// list's [top] level (in no item), in a Done section, inside the folded
/// item, and for an item, its [marker].
typedef _Context = ({
  List<Frame> frames,
  bool top,
  bool done,
  bool folded,
  Marker? marker,
});

bool _sameContext(_Context a, _Context b) =>
    a.top == b.top &&
    a.done == b.done &&
    a.folded == b.folded &&
    a.marker == b.marker &&
    _frames.equals(a.frames, b.frames);

/// A node's looks as derived last, with what they were derived in.
typedef _Cached = ({
  _Context context,
  AddItemPlace? addItems,
  DoneSections? sections,
  List<RowLook> looks,
});

final _cache = Expando<_Cached>('looks');

/// One part of what a container shows: a child node, or a row of its own.
sealed class _Part {
  const _Part();
}

/// A child [node] and the context it shows in, but its frames.
final class _Child extends _Part {
  const _Child(
    this.node, {
    required this.top,
    required this.done,
    required this.folded,
    this.marker,
  });

  final DocBlock node;
  final bool top;
  final bool done;
  final bool folded;
  final Marker? marker;
}

/// A row of a list's own (an Add item button, a Done heading): its [look]
/// in the frames it gets.
final class _Own extends _Part {
  const _Own(this.look);

  final RowLook Function(List<Frame> frames) look;
}
