import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../tree/inlines.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../commit.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';
import 'text_commands.dart';
import 'text_places.dart';

/// [format] toggled over [selection], per text leaf: taken off where
/// every character has it, else put on all of it. A bare link takes it
/// whole; code takes the other formats off its text. Spans delimiters
/// cannot write snap to edges that can.
Edit toggleStyle(ShownNote note, TextSelection selection, TextFormat format) {
  final ranges = _ranges(note, selection);
  final off = ranges.every(
    (range) => Iterable<int>.generate(range.end - range.start).every(
      (index) => range.text.formattingAt(range.start + index).has(format),
    ),
  );
  final fresh = note.tree.freshBlockIds.iterator;
  Formatting changed(Formatting formatting) => switch ((format, off)) {
    (TextFormat.code, false) => Formatting({TextFormat.code}, formatting.link),
    _ => formatting.withFormat(format, on: !off),
  };
  final changes = [
    for (final range in ranges)
      if (_withBareLinks(range) case (:final from, :final to))
        withText(
          note,
          range.slot,
          range.text.reformatted(from, to, changed),
          fresh,
        ),
  ];
  return Edit(
    replaced: {for (final change in changes) ...change.replaced},
    selection: selection,
  );
}

typedef _Range = ({Slot slot, VisibleText text, int start, int end});

/// The stretch of each text leaf's text [selection] covers, if any.
List<_Range> _ranges(ShownNote note, TextSelection selection) {
  final (start, end) = ordered(note, selection);
  final (first, last) = (note.rowOf(start.slot)!, note.rowOf(end.slot)!);
  return [
    for (final (index, row)
        in note.rows.indexed.skip(first).take(last - first + 1))
      if (row case TextRow(slot: final LeafSlot slot)
          when note.tree.blockOf(slot.leaf) is TextLeaf)
        (
          slot: slot,
          text: note.textOf(slot),
          start: index == first ? start.offset : 0,
          end: index == last ? end.offset : note.textOf(slot).length,
        ),
  ].where((range) => range.start < range.end).toList();
}

/// The stretch of [range] to format: grown over the whole of each bare
/// link it touches.
({int from, int to}) _withBareLinks(_Range range) {
  final links = range.text.placedPieces.where(
    (entry) =>
        entry.$2.formatting.link?.style == LinkStyle.extendedAutolink &&
        entry.$1 < range.end &&
        entry.$1 + entry.$2.length > range.start,
  );
  return (
    from: [range.start, ...links.map((entry) => entry.$1)].min,
    to: [range.end, ...links.map((entry) => entry.$1 + entry.$2.length)].max,
  );
}
