import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import 'slot.dart';

/// How Visual edit shows checked items in Done sections: those at a
/// list's top level after its open ones (a view; the file's order stays).
final class DoneSections {
  DoneSections({
    Set<BlockId> held = const {},
    Set<BlockId> collapsed = const {},
  }) : held = Set.unmodifiable(held),
       collapsed = Set.unmodifiable(collapsed);

  /// Items whose box changed but which show where they were until the
  /// change settles.
  final Set<BlockId> held;

  /// Lists whose Done section is collapsed: its items do not show.
  final Set<BlockId> collapsed;

  /// Whether [item] shows in its list's Done section.
  bool holds(ItemBlock item) =>
      (item.checked ?? false) != held.contains(item.id);
}

/// One row of what Visual edit shows, in the order it shows.
sealed class Row {
  Row(List<ContainerBlock> path, {required this.done})
    : path = List.unmodifiable(path);

  /// The quotes, lists and items it is in, outermost first.
  final List<ContainerBlock> path;

  /// Whether it shows in a Done section.
  final bool done;
}

/// A row that shows text: a text leaf, a code block, an item's own text
/// place, or a gap.
final class TextRow extends Row {
  TextRow(this.slot, super.path, {required super.done});

  final Slot slot;
}

/// A block without text, shown as a whole: a table, rule, HTML block,
/// link definitions or front matter.
final class BlockRow extends Row {
  BlockRow(this.leaf, super.path, {required super.done});

  final LeafBlock leaf;
}

/// The rows [root] shows with [gaps] among its blocks, checked items in
/// [done] sections if given.
List<Row> rowsOf(RootBlock root, List<Gap> gaps, DoneSections? done) => _Rows(
  groupBy(gaps, (gap) => (gap.container, gap.after)),
  done,
).of(root, const [], done: false).toList();

final class _Rows {
  _Rows(this._gaps, this._done);

  final Map<(BlockId, BlockId?), List<Gap>> _gaps;
  final DoneSections? _done;

  Iterable<Row> of(
    ContainerBlock container,
    List<ContainerBlock> path, {
    required bool done,
  }) {
    final inner = switch (container) {
      RootBlock() || ListBlock() => path,
      _ => [...path, container],
    };
    Iterable<Row> gapsAfter(BlockId? after) => [
      for (final gap in _gaps[(container.id, after)] ?? const <Gap>[])
        TextRow(GapSlot(gap.id), inner, done: done),
    ];
    return [
      if (container is ItemBlock && ownsSlot(container))
        TextRow(ItemSlot(container.id), inner, done: done),
      ...gapsAfter(null),
      for (final (child, inDone) in _shown(container, path, done: done)) ...[
        ..._child(child, container, inner, done: inDone),
        ...gapsAfter(child.id),
      ],
    ];
  }

  Iterable<Row> _child(
    Block child,
    ContainerBlock container,
    List<ContainerBlock> inner, {
    required bool done,
  }) => switch (child) {
    TextLeaf() ||
    CodeBlock() => [TextRow(LeafSlot(child.id), inner, done: done)],
    final LeafBlock leaf => [BlockRow(leaf, inner, done: done)],
    final ContainerBlock block => of(
      block,
      container is ListBlock ? [...inner, container] : inner,
      done: done,
    ),
  };

  /// [container]'s children in the order they show, with whether each
  /// shows in a Done section: a top-level list's open items, then its
  /// checked ones unless collapsed.
  Iterable<(Block, bool)> _shown(
    ContainerBlock container,
    List<ContainerBlock> path, {
    required bool done,
  }) {
    final sections = _done;
    if (sections == null ||
        container is! ListBlock ||
        path.any((block) => block is ItemBlock)) {
      return container.children.map((child) => (child, done));
    }
    final checked = container.items.where(sections.holds);
    return [
      for (final item in container.items)
        if (!sections.holds(item)) (item, false),
      if (!sections.collapsed.contains(container.id))
        for (final item in checked) (item, true),
    ];
  }
}

/// Whether [item] shows a text place of its own at its start: it has no
/// block, or its first block is a list.
bool ownsSlot(ItemBlock item) => switch (item.children.firstOrNull) {
  null || ListBlock() => true,
  _ => false,
};
