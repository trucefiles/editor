import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../tree/inlines.dart';
import '../../view/rows.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../change.dart';
import '../selection.dart';
import '../text_places.dart';
import 'text_commands.dart';

/// [format] toggled over [selection], per text node: taken off where
/// every character has it, else put on all of it. A bare link takes it
/// whole. Code takes the other formats off its text, and goes on text
/// only: a line break inside stays one (a soft break turns into the space
/// it shows as). The selection stays.
Change toggleStyle(ViewRows view, TextSelection selection, TextFormat format) {
  final ranges = _ranges(view, selection);
  final off = ranges.every(
    (range) => range.text
        .slice(range.start, range.end)
        .pieces
        .whereType<TextPiece>()
        .every((piece) => piece.formatting.has(format)),
  );
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
  return (
    doc: ranges.fold(view.doc, (doc, range) {
      final (:from, :to) = _withBareLinks(range);
      return withTextAt(
        doc,
        range.leaf.id,
        range.text.replaced(from, to, changed(range.text.slice(from, to))),
      );
    }),
    selection: selection,
  );
}

typedef _Range = ({TextNode leaf, VisibleText text, int start, int end});

/// The stretch of each text node's text [selection] covers, if any.
List<_Range> _ranges(ViewRows view, TextSelection selection) {
  final (start, end) = ordered(view, selection);
  final (first, last) = (view.rowOf(start.leaf)!, view.rowOf(end.leaf)!);
  return [
    for (final (index, row)
        in view.rows.indexed.skip(first).take(last - first + 1))
      if (row case TextRow(leaf: final TextNode leaf))
        (
          leaf: leaf,
          text: leaf.text,
          start: index == first ? start.offset : 0,
          end: index == last ? end.offset : leaf.text.length,
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
