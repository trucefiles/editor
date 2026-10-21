import '../document/markdown_document.dart';
import '../lines/line_id.dart';
import '../tree/blocks.dart';

/// One part of what an editor shows of a document, in display order.
sealed class DisplayEntry {
  const DisplayEntry();
}

/// The leaf block whose first line is [leaf], shown as its text.
final class LeafEntry extends DisplayEntry {
  const LeafEntry(this.leaf);

  final LineId leaf;
}

/// Line [line], shown as it is in the file.
final class LineEntry extends DisplayEntry {
  const LineEntry(this.line);

  final LineId line;
}

/// The table whose first line is [leaf], drawn as a grid.
final class TableEntry extends DisplayEntry {
  const TableEntry(this.leaf);

  final LineId leaf;
}

/// The heading of the "Done" section of the list [list], over its [count]
/// checked items; they follow unless [collapsed]. Not a line.
final class DoneHeadingEntry extends DisplayEntry {
  const DoneHeadingEntry(
    this.list, {
    required this.count,
    required this.collapsed,
  });

  /// The list, by its first line.
  final LineId list;
  final int count;
  final bool collapsed;
}

/// The button that adds an item to the list [list], of the kind of the
/// item [anchor]: before it if [before], else after it and its subitems.
/// Not a line.
final class AddItemEntry extends DisplayEntry {
  const AddItemEntry(this.list, this.anchor, {required this.before});

  /// The list, by its first line.
  final LineId list;
  final LineId anchor;
  final bool before;
}

/// Where a list's add button goes.
enum AddItemPlace { top, bottom }

/// How to arrange a document for display.
final class Arrangement {
  /// Every line as it is in the file, in file order.
  const Arrangement.lines()
    : blocks = false,
      doneSection = false,
      collapsed = const {},
      addItems = null,
      raw = const {};

  /// Every leaf block as its text, in file order but for the "Done"
  /// sections; tables drawn.
  const Arrangement.blocks({
    this.doneSection = false,
    this.collapsed = const {},
    this.addItems,
    this.raw = const {},
  }) : blocks = true;

  /// Whether leaf blocks show, else lines.
  final bool blocks;

  /// Each list's checked items, with their subitems, after its open ones
  /// under a "Done" heading; for lists in no other block.
  final bool doneSection;

  /// Lists, by their first line, whose "Done" section hides its items.
  final Set<LineId> collapsed;

  /// Where each list in no other block gets its add button; none if
  /// `null`.
  final AddItemPlace? addItems;

  /// Tables, by their first line, shown as their text.
  final Set<LineId> raw;

  /// What shows of [document], in display order. Every line shows once,
  /// except a collapsed "Done" section's.
  List<DisplayEntry> of(MarkdownDocument document) {
    if (!blocks) {
      return [for (final line in document.lines) LineEntry(line.id)];
    }
    final done = doneSection ? document.outline.doneIds : const <LineId>{};
    return [
      for (final block in document.root.children)
        ...switch (block) {
          ListBlock() => _list(document, block, done),
          _ => block.leaves.map(_entryOf),
        },
    ];
  }

  DisplayEntry _entryOf(LeafBlock leaf) =>
      leaf is TableBlock && !raw.contains(leaf.id)
      ? TableEntry(leaf.id)
      : LeafEntry(leaf.id);

  /// The entries of [list], whose lines in [done] show as done; blank
  /// lines that end it show after its "Done" section, before what
  /// follows it.
  List<DisplayEntry> _list(
    MarkdownDocument document,
    ListBlock list,
    Set<LineId> done,
  ) {
    final id = list.firstLine.id;
    bool isDone(LeafBlock leaf) => done.contains(leaf.id);
    final items = [
      for (final item in document.outline.items)
        if (item.ancestors.contains(list)) item,
    ];
    final openItems = items.where((item) => !done.contains(item.markerLine));
    final blankEnd = list.children.reversed
        .takeWhile((block) => block is BlankBlock)
        .length;
    final leaves = list.leaves.take(list.leaves.length - blankEnd);
    final checked = leaves.where(isDone).map(_entryOf).toList();
    final isCollapsed = collapsed.contains(id);
    return [
      if (addItems == AddItemPlace.top)
        AddItemEntry(
          id,
          (openItems.firstOrNull ?? items.first).markerLine,
          before: true,
        ),
      ...leaves.where((leaf) => !isDone(leaf)).map(_entryOf),
      if (addItems == AddItemPlace.bottom)
        AddItemEntry(
          id,
          (openItems.lastOrNull ?? items.last).markerLine,
          before: false,
        ),
      if (checked.isNotEmpty) ...[
        DoneHeadingEntry(
          id,
          count: items.where((item) => item.isChecked).length,
          collapsed: isCollapsed,
        ),
        if (!isCollapsed) ...checked,
      ],
      ...list.leaves.skip(list.leaves.length - blankEnd).map(_entryOf),
    ];
  }
}
