import 'package:collection/collection.dart';

import '../../tree/inlines.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import 'text_commands.dart';

/// The link dialog's result: [range], within one text place, showing
/// [text] (the [url] if empty) as a link to [url], the caret after it.
/// Text left as it was keeps its formats; a link already there that
/// leads to [url] keeps its spelling.
Edit setLink(ShownNote note, TextSelection range, String text, String url) {
  final (start, end) = ordered(note, range);
  assert(start.slot == end.slot, 'a link within one text place');
  final old = note.textOf(start.slot).slice(start.offset, end.offset);
  final mark = switch (old.text.isEmpty ? null : old.formattingAt(0).link) {
    final link? when link.destination == url => link,
    _ => LinkMark(destination: url, style: LinkStyle.inline),
  };
  final shows = text.isEmpty ? url : text;
  return typed(
    note,
    start,
    end.offset,
    shows == old.text
        ? old.reformatted(0, old.length, (it) => it.withLink(mark))
        : VisibleText([TextPiece(shows, Formatting.plain.withLink(mark))]),
  );
}

/// Whether the link at [at] can be removed: there is one, and it is not
/// text GFM reads as a link anyway.
bool canRemoveLink(ShownNote note, Place at) =>
    switch (_linkAt(note.textOf(at.slot), at.offset)?.mark.style) {
      null || LinkStyle.extendedAutolink => false,
      _ => true,
    };

/// The link at [at] removed, its text kept; the caret after the text.
Edit removeLink(ShownNote note, Place at) {
  final text = note.textOf(at.slot);
  final (mark: _, :from, :to) = _linkAt(text, at.offset)!;
  return typed(
    note,
    Place(at.slot, from),
    to,
    text.slice(from, to).reformatted(0, to - from, (it) => it.withLink(null)),
  );
}

/// The link of the character at [offset] in [text], else of the one
/// before it, with the stretch it spans; `null` if neither is a link's.
({LinkMark mark, int from, int to})? _linkAt(VisibleText text, int offset) {
  final mark = [offset, offset - 1]
      .where((index) => index >= 0 && index < text.length)
      .map((index) => text.formattingAt(index).link)
      .nonNulls
      .firstOrNull;
  if (mark == null) return null;
  final pieces = text.placedPieces
      .where((entry) => identical(entry.$2.formatting.link, mark))
      .toList();
  return (
    mark: mark,
    from: pieces.first.$1,
    to: pieces.last.$1 + pieces.last.$2.length,
  );
}
