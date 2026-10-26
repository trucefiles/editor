import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../commit.dart';
import '../common_ends.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import '../shown/slot.dart';
import '../shown/typing_style.dart';
import 'delete_across.dart';
import 'text_places.dart';

/// [text] typed at [at] in [formatting].
Edit insertText(
  ShownDocument document,
  Place at,
  String text,
  Formatting formatting,
) => typed(document, at, at.offset, VisibleText([TextPiece(text, formatting)]));

/// The text in [range] replaced by [text], keeping the formatting of
/// what stays.
Edit replaceText(ShownDocument document, TextSelection range, String text) {
  final (start, end) = ordered(document, range);
  assert(start.slot == end.slot, 'a replacement within one text place');
  final shown = document.textOf(start.slot);
  final old = shown.text.substring(start.offset, end.offset);
  final (:head, :tail) = commonEnds(old, text);
  final from = start.offset + head;
  final to = end.offset - tail;
  final formatting = switch ((from < to, from > 0)) {
    (true, _) => shown.formattingAt(from),
    (false, true) => shown.formattingAt(from - 1),
    (false, false) => Formatting.plain,
  };
  return typed(
    document,
    Place(start.slot, from),
    to,
    VisibleText([
      TextPiece(text.substring(head, text.length - tail), formatting),
    ]),
  );
}

/// The text in [range] removed; across text places, see [deleteAcross].
Edit deleteRange(ShownDocument document, TextSelection range) {
  final (start, end) = ordered(document, range);
  return start.slot == end.slot
      ? typed(document, start, end.offset, VisibleText.empty)
      : deleteAcross(document, start, end);
}

/// [slot]'s text joined to the text shown in the row above (a text
/// place): the text of the two places from [slot]'s start back to the
/// end of the one above removed.
Edit joinWithPrevious(ShownDocument document, Slot slot) {
  final above = _textRow(document, document.rowOf(slot)! - 1);
  return deleteAcross(
    document,
    Place(above, document.textOf(above).length),
    Place(slot, 0),
  );
}

/// The text shown in the row below (a text place) joined to [slot]'s.
Edit joinWithNext(ShownDocument document, Slot slot) {
  final below = _textRow(document, document.rowOf(slot)! + 1);
  return deleteAcross(
    document,
    Place(slot, document.textOf(slot).length),
    Place(below, 0),
  );
}

Slot _textRow(ShownDocument document, int index) =>
    switch (document.rows[index]) {
      TextRow(:final slot) => slot,
      final row => throw ArgumentError.value(row, 'row', 'no text place'),
    };

/// A line break put in at [at], in the typing style there, dropping the
/// spaces after it (see [newLineStart]); code holds no line break, so it
/// ends there and goes on after it.
Edit lineBreak(ShownDocument document, Place at) => typed(
  document,
  at,
  newLineStart(document.textOf(at.slot), at.offset),
  VisibleText([
    HardBreakPiece(
      typingStyleAt(document, at).withFormat(TextFormat.code, on: false),
    ),
  ]),
);

/// Where a new line that [text] breaks into at [at] starts: past the
/// spaces there, which it drops, as a line does not start with them.
/// Spaces in code are code, so they stay.
int newLineStart(VisibleText text, int at) =>
    at +
    Iterable<int>.generate(text.length - at, (index) => at + index)
        .takeWhile(
          (offset) =>
              const [' ', '\t'].contains(text.text[offset]) &&
              !text.formattingAt(offset).has(TextFormat.code),
        )
        .length;

/// The text from [from] to [to] in its text place replaced by [insert],
/// the caret after it.
Edit typed(ShownDocument document, Place from, int to, VisibleText insert) {
  final text = document.textOf(from.slot).replaced(from.offset, to, insert);
  final change = withText(
    document,
    from.slot,
    text,
    document.tree.freshBlockIds.iterator,
  );
  return Edit(
    replaced: change.replaced,
    gaps: change.gaps,
    tails: change.tails,
    selection: TextSelection.caret(
      Place(change.slot, from.offset + insert.length),
    ),
  );
}

/// [range]'s places, first in shown order first.
(Place, Place) ordered(ShownDocument document, TextSelection range) {
  final (base, extent) = (range.base, range.extent);
  final order = switch ((
    document.rowOf(base.slot),
    document.rowOf(extent.slot),
  )) {
    (final a?, final b?) when a != b => a.compareTo(b),
    _ => base.offset.compareTo(extent.offset),
  };
  return order <= 0 ? (base, extent) : (extent, base);
}
