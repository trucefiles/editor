import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../commit.dart';
import '../common_ends.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';
import 'delete_across.dart';
import 'text_places.dart';

/// [text] typed at [at] in [formatting].
Edit insertText(ShownNote note, Place at, String text, Formatting formatting) =>
    _typed(note, at, at.offset, VisibleText([TextPiece(text, formatting)]));

/// The text in [range] replaced by [text], keeping the formatting of
/// what stays.
Edit replaceText(ShownNote note, TextSelection range, String text) {
  final (start, end) = ordered(note, range);
  assert(start.slot == end.slot, 'a replacement within one text place');
  final shown = note.textOf(start.slot);
  final old = shown.text.substring(start.offset, end.offset);
  final (:head, :tail) = commonEnds(old, text);
  final from = start.offset + head;
  final to = end.offset - tail;
  final formatting = switch ((from < to, from > 0)) {
    (true, _) => shown.formattingAt(from),
    (false, true) => shown.formattingAt(from - 1),
    (false, false) => Formatting.plain,
  };
  return _typed(
    note,
    Place(start.slot, from),
    to,
    VisibleText([
      TextPiece(text.substring(head, text.length - tail), formatting),
    ]),
  );
}

/// The text in [range] removed; across text places, see [deleteAcross].
Edit deleteRange(ShownNote note, TextSelection range) {
  final (start, end) = ordered(note, range);
  return start.slot == end.slot
      ? _typed(note, start, end.offset, VisibleText.empty)
      : deleteAcross(note, start, end);
}

/// [slot]'s text joined to the text shown in the row above (a text
/// place): the text of the two places from [slot]'s start back to the
/// end of the one above removed.
Edit joinWithPrevious(ShownNote note, Slot slot) {
  final above = _textRow(note, note.rowOf(slot)! - 1);
  return deleteAcross(
    note,
    Place(above, note.textOf(above).length),
    Place(slot, 0),
  );
}

/// The text shown in the row below (a text place) joined to [slot]'s.
Edit joinWithNext(ShownNote note, Slot slot) {
  final below = _textRow(note, note.rowOf(slot)! + 1);
  return deleteAcross(
    note,
    Place(slot, note.textOf(slot).length),
    Place(below, 0),
  );
}

Slot _textRow(ShownNote note, int index) => switch (note.rows[index]) {
  TextRow(:final slot) => slot,
  final row => throw ArgumentError.value(row, 'row', 'no text place'),
};

/// A line break put in at [at].
Edit lineBreak(ShownNote note, Place at) {
  final shown = note.textOf(at.slot);
  return _typed(
    note,
    at,
    at.offset,
    VisibleText([
      HardBreakPiece(
        at.offset > 0 ? shown.formattingAt(at.offset - 1) : Formatting.plain,
      ),
    ]),
  );
}

/// The text from [from] to [to] in its text place replaced by [insert],
/// the caret after it.
Edit _typed(ShownNote note, Place from, int to, VisibleText insert) {
  final text = note.textOf(from.slot).replaced(from.offset, to, insert);
  final change = withText(
    note,
    from.slot,
    text,
    note.tree.freshBlockIds.iterator,
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
(Place, Place) ordered(ShownNote note, TextSelection range) {
  final (base, extent) = (range.base, range.extent);
  final order = switch ((note.rowOf(base.slot), note.rowOf(extent.slot))) {
    (final a?, final b?) when a != b => a.compareTo(b),
    _ => base.offset.compareTo(extent.offset),
  };
  return order <= 0 ? (base, extent) : (extent, base);
}
