import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../tree/inlines.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../commit.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import '../shown/slot.dart';
import 'text_commands.dart';
import 'text_places.dart';

/// [format] toggled over [selection], per text leaf: taken off where
/// every character has it, else put on all of it. A bare link takes it
/// whole. Code takes the other formats off its text, and goes on text
/// only: a line break inside stays one (a soft break turns into the
/// space it shows as). Spans delimiters cannot write snap to edges that
/// can.
Edit toggleStyle(
  ShownDocument document,
  TextSelection selection,
  TextFormat format,
) {
  final ranges = _ranges(document, selection);
  final off = ranges.every(
    (range) => range.text
        .slice(range.start, range.end)
        .pieces
        .whereType<TextPiece>()
        .every((piece) => piece.formatting.has(format)),
  );
  final fresh = document.tree.freshBlockIds.iterator;
  VisibleText changed(VisibleText text) => switch ((format, off)) {
    (TextFormat.code, false) => VisibleText([
      for (final piece in text.pieces)
        switch (piece) {
          TextPiece(:final text, :final formatting) => TextPiece(
            text,
            Formatting({TextFormat.code}, formatting.link),
          ),
          SoftBreakPiece(:final formatting) => TextPiece(
            ' ',
            Formatting({TextFormat.code}, formatting.link),
          ),
          _ => piece,
        },
    ]),
    _ => text.reformatted(
      0,
      text.length,
      (formatting) => formatting.withFormat(format, on: !off),
    ),
  };
  final changes = [
    for (final range in ranges)
      if (_withBareLinks(range) case (:final from, :final to))
        withText(
          document,
          range.slot,
          range.text.replaced(from, to, changed(range.text.slice(from, to))),
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
List<_Range> _ranges(ShownDocument document, TextSelection selection) {
  final (start, end) = ordered(document, selection);
  final (first, last) = (
    document.rowOf(start.slot)!,
    document.rowOf(end.slot)!,
  );
  return [
    for (final (index, row)
        in document.rows.indexed.skip(first).take(last - first + 1))
      if (row case TextRow(slot: final LeafSlot slot)
          when document.tree.blockOf(slot.leaf) is TextLeaf)
        (
          slot: slot,
          text: document.textOf(slot),
          start: index == first ? start.offset : 0,
          end: index == last ? end.offset : document.textOf(slot).length,
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
