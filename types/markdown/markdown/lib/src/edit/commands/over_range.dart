/// Keys pressed over a selection: what it holds goes first.
library;

import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';
import 'line_after.dart';
import 'line_in_place.dart';
import 'text_commands.dart';

/// [view]'s document with what [selection] holds taken away, the caret
/// where it was: its text removed, or the block selected whole replaced
/// by an empty line, as typing replaces one selected character; right
/// after a block, a new empty line after it to type in.
Edited cleared(ViewRows view, Selection selection) => switch (selection) {
  TextSelection(isCaret: true) => (doc: view.doc, selection: selection),
  final TextSelection range => settled(
    deleteRange(view, range),
    before: view.doc,
  ),
  BlockSelection(:final block) => settled(
    lineInPlace(view, block),
    before: view.doc,
  ),
  BlockCaret(:final block) => settled(lineAfter(view, block), before: view.doc),
};

/// [edit] made at the caret once what [selection] holds is taken away.
Edited overRange(
  ViewRows view,
  Selection selection,
  Change Function(ViewRows view, Place at) edit,
) => atCaret(view, cleared(view, selection), edit);

/// [edit] made at the caret [edited] leaves, shown as [view] shows its
/// document; [edited] as is when it leaves no text caret.
Edited atCaret(
  ViewRows view,
  Edited edited,
  Change Function(ViewRows view, Place at) edit,
) => switch (edited.selection) {
  TextSelection(:final extent) => settled(
    edit(ViewRows(edited.doc, done: view.done), extent),
    before: edited.doc,
  ),
  _ => edited,
};
