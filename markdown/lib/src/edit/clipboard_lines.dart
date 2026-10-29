/// The lines a paste puts in: plain text from outside, or a fragment
/// copied in the app with its styles. Lines hold no line breaks and no
/// frames; where they land decides what each becomes.
library;

import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart' show splitLines;

import '../view/rows.dart';
import '../visible/formatting.dart';
import '../visible/visible_text.dart';
import 'commands/text_commands.dart';
import 'selection.dart';

/// Plain [text] as lines in [formatting] (the typing style), split at
/// each line break.
List<VisibleText> plainLines(String text, Formatting formatting) => [
  for (final line in splitLines(text))
    line.isEmpty
        ? VisibleText.empty
        : VisibleText([TextPiece(line, formatting)]),
];

/// What [range] of [document] shows, as lines with their styles: one per
/// text place it touches, split at line breaks. Soft breaks are spaces;
/// objects (images, inline HTML) stay behind, as they are no style.
List<VisibleText> copiedLines(ViewRows view, TextSelection range) {
  final (start, end) = ordered(view, range);
  final rows = view.rows.sublist(
    view.rowOf(start.leaf)!,
    view.rowOf(end.leaf)! + 1,
  );
  return [
    for (final TextRow(:leaf) in rows.whereType<TextRow>())
      ..._lines(
        textOf(leaf).slice(
          leaf.id == start.leaf ? start.offset : 0,
          leaf.id == end.leaf ? end.offset : textOf(leaf).length,
        ),
      ),
  ];
}

/// [lines] as the plain text the system clipboard gets.
String plainTextOf(List<VisibleText> lines) =>
    lines.map((line) => line.text).join('\n');

/// [text] split at its line breaks, its soft breaks spaces, without
/// objects.
List<VisibleText> _lines(VisibleText text) => [
  for (final line in [
    null,
    ..._pieces(text),
  ].splitBefore((piece) => piece == null))
    VisibleText(line.nonNulls),
];

/// [text]'s pieces as lines hold them; `null` for a line break.
Iterable<VisiblePiece?> _pieces(VisibleText text) => text.pieces.expand(
  (piece) => switch (piece) {
    TextPiece(:final text, :final formatting) => [
      for (final (index, part) in text.split('\n').indexed) ...[
        if (index > 0) null,
        if (part.isNotEmpty) TextPiece(part, formatting),
      ],
    ],
    SoftBreakPiece(:final formatting) => [TextPiece(' ', formatting)],
    HardBreakPiece() => [null],
    ObjectPiece() => const [],
  },
);
