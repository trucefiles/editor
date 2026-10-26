/// Keys pressed over a selection: its text goes first.
library;

import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';
import 'text_commands.dart';

/// [view]'s document with the text in [range] removed, the caret where it
/// was.
Edited cleared(ViewRows view, TextSelection range) => range.isCaret
    ? (doc: view.doc, selection: range)
    : settled(deleteRange(view, range));

/// [edit] made at the caret once the text in [range] is removed.
Edited overRange(
  ViewRows view,
  TextSelection range,
  Change Function(ViewRows view, Place at) edit,
) => atCaret(view, cleared(view, range), edit);

/// [edit] made at the caret [edited] leaves, shown as [view] shows its
/// document; [edited] as is when it leaves no text caret.
Edited atCaret(
  ViewRows view,
  Edited edited,
  Change Function(ViewRows view, Place at) edit,
) => switch (edited.selection) {
  TextSelection(:final extent) => settled(
    edit(ViewRows(edited.doc, done: view.done), extent),
  ),
  _ => edited,
};
