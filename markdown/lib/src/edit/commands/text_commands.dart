/// Commands that change the text of text places: typing, replacing,
/// deleting, joining, line breaks.
library;

import 'package:characters/characters.dart';
import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../view/rows.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../change.dart';
import '../selection.dart';
import '../text_places.dart';
import '../typing_style.dart';
import 'delete_across.dart';

/// [text] typed at [at] in [formatting].
Change insertText(
  ViewRows view,
  Place at,
  String text,
  Formatting formatting,
) => typed(view, at, at.offset, VisibleText([TextPiece(text, formatting)]));

/// The text in [range], within one text place, replaced by [text], as an
/// input method does: the text both share at their start and end keeps
/// its formatting; what changed takes the formatting of the first
/// character it replaced (else of the one before). The caret goes after
/// the new text.
Change replaceText(ViewRows view, TextSelection range, String text) {
  final (start, end) = ordered(view, range);
  assert(start.leaf == end.leaf, 'a replacement within one text place');
  final shown = textAt(view.doc, start.leaf);
  final old = shown.text.substring(start.offset, end.offset);
  final (:head, :tail) = _commonEnds(old, text);
  final from = start.offset + head;
  final to = end.offset - tail;
  final formatting = switch ((from < to, from > 0)) {
    (true, _) => shown.formattingAt(from),
    (false, true) => shown.formattingAt(from - 1),
    (false, false) => Formatting.plain,
  };
  final (:doc, selection: _) = typed(
    view,
    Place(start.leaf, from),
    to,
    VisibleText([
      TextPiece(text.substring(head, text.length - tail), formatting),
    ]),
  );
  // After the whole new text, even where only its middle changed.
  return (
    doc: doc,
    selection: TextSelection.caret(
      Place(start.leaf, start.offset + text.length),
    ),
  );
}

/// The text in [range] removed; across text places, see [deleteAcross].
Change deleteRange(ViewRows view, TextSelection range) {
  final (start, end) = ordered(view, range);
  return start.leaf == end.leaf
      ? typed(view, start, end.offset, VisibleText.empty)
      : deleteAcross(view, start, end);
}

/// Backspace at the start of [at]'s text place: the text place shown in
/// the row above joins it (see [deleteAcross]).
Change joinWithPrevious(ViewRows view, Place at) {
  final above = _textRow(view, view.rowOf(at.leaf)! - 1);
  return deleteAcross(
    view,
    Place(above.leaf.id, textOf(above.leaf).length),
    Place(at.leaf, 0),
  );
}

/// Delete at the end of [at]'s text place: the text place shown in the
/// row below joins it; code that holds any keeps its place, and the caret
/// goes to its start (as Backspace after code goes to its end). An empty
/// text place goes instead, if nothing else is in its item or quote, so
/// the row below keeps its item and box.
Change joinWithNext(ViewRows view, Place at) {
  final below = _textRow(view, view.rowOf(at.leaf)! + 1);
  if (below.leaf case CodeNode(:final code) when code.isNotEmpty) {
    return (
      doc: view.doc,
      selection: TextSelection.caret(Place(below.leaf.id, 0)),
    );
  }
  if (_emptyGone(view.doc, at.leaf) case final doc?) {
    return (doc: doc, selection: TextSelection.caret(Place(below.leaf.id, 0)));
  }
  return deleteAcross(
    view,
    Place(at.leaf, textAt(view.doc, at.leaf).length),
    Place(below.leaf.id, 0),
  );
}

/// [doc] without [leaf], if it is an empty text place alone in its item
/// or quote (or at the top level), along with the items, lists and
/// quotes it alone fills; `null` otherwise.
DocTree? _emptyGone(DocTree doc, NodeId leaf) {
  if (textAt(doc, leaf).text.isNotEmpty) return null;
  final parent = doc.parentOf(leaf)!;
  if (parent is! DocRoot && parent.children.length > 1) return null;
  final alone = doc
      .pathOf(leaf)
      .reversed
      .takeWhile((container) => container is! DocRoot)
      .takeWhile((container) => container.children.length == 1)
      .lastOrNull;
  return doc.edited({alone?.id ?? leaf: const []});
}

TextRow _textRow(ViewRows view, int index) => switch (view.rows[index]) {
  final TextRow row => row,
  final row => throw ArgumentError.value(row, 'row', 'no text place'),
};

/// A line break put in at [at], in the typing style there, dropping the
/// spaces after it (see [newLineStart]).
Change lineBreak(ViewRows view, Place at) => typed(
  view,
  at,
  newLineStart(textAt(view.doc, at.leaf), at.offset),
  VisibleText([
    HardBreakPiece(
      typingStyleAt(view.doc, at).withFormat(TextFormat.code, on: false),
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
Change typed(ViewRows view, Place from, int to, VisibleText insert) => (
  doc: withTextAt(
    view.doc,
    from.leaf,
    textAt(view.doc, from.leaf).replaced(from.offset, to, insert),
  ),
  selection: TextSelection.caret(Place(from.leaf, from.offset + insert.length)),
);

/// [range]'s places, the first shown first.
(Place, Place) ordered(ViewRows view, TextSelection range) {
  final (base, extent) = (range.base, range.extent);
  final order = switch ((view.rowOf(base.leaf), view.rowOf(extent.leaf))) {
    (final a?, final b?) when a != b => a.compareTo(b),
    _ => base.offset.compareTo(extent.offset),
  };
  return order <= 0 ? (base, extent) : (extent, base);
}

/// The offset of the character before [offset] in [text], as the user
/// sees characters.
int graphemeBefore(String text, int offset) =>
    offset - text.substring(0, offset).characters.last.length;

/// The offset after the character at [offset] in [text].
int graphemeAfter(String text, int offset) =>
    offset + text.substring(offset).characters.first.length;

/// How many characters [a] and [b] share at their start ([head]) and,
/// after that, at their end ([tail]).
({int head, int tail}) _commonEnds(String a, String b) {
  int same(String a, String b) =>
      Iterable<int>.generate(a.length < b.length ? a.length : b.length)
          .takeWhile((index) => a[index] == b[index])
          .length;
  String reversed(String text) => text.split('').reversed.join();
  final head = same(a, b);
  return (
    head: head,
    tail: same(reversed(a.substring(head)), reversed(b.substring(head))),
  );
}
