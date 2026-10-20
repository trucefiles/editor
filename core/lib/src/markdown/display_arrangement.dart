import 'line_id.dart';
import 'markdown_line.dart';
import 'markdown_lines.dart';
import 'outline.dart';
import 'syntax/line_kinds.dart';

/// One part of what an editor shows of a document, in display order.
sealed class DisplayEntry {
  const DisplayEntry();
}

/// Line [id], of [kind].
final class LineEntry extends DisplayEntry {
  const LineEntry(this.id, this.kind);

  final LineId id;
  final LineKind kind;
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

/// A table drawn from its lines [ids]: header, delimiter row and rows.
final class TableEntry extends DisplayEntry {
  const TableEntry(this.ids);

  final List<LineId> ids;
}

/// The image of line [id], which holds only the image.
final class ImageEntry extends DisplayEntry {
  const ImageEntry(this.id, {required this.url, required this.alt});

  final LineId id;
  final String url;
  final String alt;
}

/// Where a list's add button goes.
enum AddItemPlace { top, bottom }

/// How to arrange a document for display.
final class Arrangement {
  const Arrangement({
    this.doneSection = false,
    this.collapsed = const {},
    this.addItems,
    this.drawBlocks = false,
    this.raw = const {},
  });

  /// Each list's checked items, with their subitems, after its open ones
  /// under a "Done" heading. Else everything in file order.
  final bool doneSection;

  /// Lists, by their first line, whose "Done" section hides its items.
  final Set<LineId> collapsed;

  /// Where each list gets its add button; none if `null`.
  final AddItemPlace? addItems;

  /// Tables and images drawn, unless in [raw].
  final bool drawBlocks;

  /// Tables and images, by their first line, shown as their lines.
  final Set<LineId> raw;

  /// What shows of [document], in display order. Every line shows once,
  /// except a collapsed "Done" section's; lines of a drawn table or image
  /// show as that.
  List<DisplayEntry> of(MarkdownLines document) {
    final done = doneSection ? document.doneIds : const <LineId>{};
    return [
      for (final part in document.outline.parts)
        ..._part(document, part, done),
    ];
  }

  List<DisplayEntry> _part(
    MarkdownLines document,
    OutlinePart part,
    Set<LineId> done,
  ) {
    final (:start, :end) = part.span;
    final lines = document.lines.sublist(start, end);
    final kinds = document.kinds.sublist(start, end);
    final first = lines.first;
    final drawn = drawBlocks && !raw.contains(first.id);
    return switch (part) {
      ListPart() => _list(document, lines, kinds, done),
      TablePart() when drawn => [
        TableEntry([for (final line in lines) line.id]),
      ],
      LinePart() when drawn && kinds.first == LineKind.plain =>
        switch (lineImage(first.raw)) {
          final image? => [
            ImageEntry(first.id, url: image.url, alt: image.alt),
          ],
          null => [LineEntry(first.id, kinds.first)],
        },
      _ => [
        for (final (i, line) in lines.indexed) LineEntry(line.id, kinds[i]),
      ],
    };
  }

  /// The entries of the list [list] of [document], whose lines have
  /// [kinds].
  List<DisplayEntry> _list(
    MarkdownLines document,
    List<MarkdownLine> list,
    List<LineKind> kinds,
    Set<LineId> done,
  ) {
    final id = list.first.id;
    final open = [
      for (final (i, line) in list.indexed)
        if (!done.contains(line.id)) LineEntry(line.id, kinds[i]),
    ];
    final checked = [
      for (final (i, line) in list.indexed)
        if (done.contains(line.id)) LineEntry(line.id, kinds[i]),
    ];
    final items = list.where(document.isItem);
    final openItems = items.where((line) => !done.contains(line.id));
    final isCollapsed = collapsed.contains(id);
    return [
      if (addItems == AddItemPlace.top)
        AddItemEntry(
          id,
          (openItems.firstOrNull ?? items.first).id,
          before: true,
        ),
      ...open,
      if (addItems == AddItemPlace.bottom)
        AddItemEntry(
          id,
          (openItems.lastOrNull ?? items.last).id,
          before: false,
        ),
      if (checked.isNotEmpty) ...[
        DoneHeadingEntry(
          id,
          count: items.where((line) => line.isChecked).length,
          collapsed: isCollapsed,
        ),
        if (!isCollapsed) ...checked,
      ],
    ];
  }
}

/// For each line [entries] show, the line shown right below it, if a line
/// is: none before a heading, a button or the end.
Map<LineId, LineId> linesShownBelow(List<DisplayEntry> entries) {
  // The lines in display order, `null` where something else shows.
  final shown = [
    for (final entry in entries)
      ...switch (entry) {
        LineEntry(:final id) || ImageEntry(:final id) => [id],
        TableEntry(:final ids) => ids,
        DoneHeadingEntry() || AddItemEntry() => const [null],
      },
  ];
  return {
    for (var i = 0; i + 1 < shown.length; i++)
      if ((shown[i], shown[i + 1]) case (final above?, final below?))
        above: below,
  };
}
