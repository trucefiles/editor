import 'line_id.dart';
import 'markdown_line.dart';
import 'markdown_lines.dart';
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

/// The heading of the "Done" section of the checklist [list], over its
/// [count] checked items; they follow unless [collapsed]. Not a line.
final class DoneHeadingEntry extends DisplayEntry {
  const DoneHeadingEntry(
    this.list, {
    required this.count,
    required this.collapsed,
  });

  /// The checklist, by its first line.
  final LineId list;
  final int count;
  final bool collapsed;
}

/// A button that adds an item to the checklist [list]: before the item
/// [anchor] if [before], else after it and its subitems. Not a line.
final class AddItemEntry extends DisplayEntry {
  const AddItemEntry(this.list, this.anchor, {required this.before});

  /// The checklist, by its first line.
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

/// Where a checklist's add button goes.
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

  /// Each checklist's checked items, with their subitems, after its open
  /// ones under a "Done" heading. Else everything in file order.
  final bool doneSection;

  /// Checklists, by their first line, whose "Done" section hides its
  /// items.
  final Set<LineId> collapsed;

  /// Where each checklist gets an add button; none if `null`.
  final AddItemPlace? addItems;

  /// Tables and images drawn, unless in [raw].
  final bool drawBlocks;

  /// Tables and images, by their first line, shown as their lines.
  final Set<LineId> raw;

  /// What shows of [document], in display order. Every line shows once,
  /// except a collapsed "Done" section's; lines of a drawn table or image
  /// show as that.
  List<DisplayEntry> of(MarkdownLines document) {
    final lines = document.lines;
    final kinds = lineKinds([for (final line in lines) line.raw]);
    final checklists = {
      for (final list in document.checklists) list.first.id: list,
    };
    final tables = {for (final (start, end) in tableRanges(kinds)) start: end};
    final done = doneSection ? document.doneIds : const <LineId>{};
    final entries = <DisplayEntry>[];
    for (var i = 0; i < lines.length;) {
      final line = lines[i];
      final drawn = drawBlocks && !raw.contains(line.id);
      if (checklists[line.id] case final list?
          when kinds[i] == LineKind.plain) {
        entries.addAll(_checklist(list, kinds.sublist(i), done));
        i += list.length;
      } else if (tables[i] case final end? when drawn) {
        entries.add(TableEntry([for (final l in lines.sublist(i, end)) l.id]));
        i = end;
      } else if (lineImage(line.raw) case final image?
          when drawn && kinds[i] == LineKind.plain) {
        entries.add(ImageEntry(line.id, url: image.url, alt: image.alt));
        i++;
      } else {
        entries.add(LineEntry(line.id, kinds[i]));
        i++;
      }
    }
    return entries;
  }

  /// The entries of the checklist [list], whose lines have [kinds].
  List<DisplayEntry> _checklist(
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
    final openItems = list.where(
      (line) => line.isItem && !done.contains(line.id),
    );
    final items = list.where((line) => line.isItem);
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
          count: list.where((line) => line.isChecked).length,
          collapsed: isCollapsed,
        ),
        if (!isCollapsed) ...checked,
      ],
    ];
  }
}
