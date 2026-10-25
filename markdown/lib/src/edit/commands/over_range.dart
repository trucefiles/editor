import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import 'text_commands.dart';

/// [document] with the text in [range] removed, the caret where it was.
Edited cleared(ShownDocument document, TextSelection range) => range.isCaret
    ? (document: document, selection: range)
    : commit(document, deleteRange(document, range));

/// [edit] made at the caret once the text in [range] is removed: a key
/// pressed over a selection.
Edited overRange(
  ShownDocument document,
  TextSelection range,
  Edit Function(ShownDocument document, Place at) edit,
) => atCaret(cleared(document, range), edit);

/// [edit] made at the caret [edited] leaves; [edited] as is when it
/// leaves no text caret (the text became a raw block).
Edited atCaret(
  Edited edited,
  Edit Function(ShownDocument document, Place at) edit,
) => switch (edited.selection) {
  TextSelection(:final extent) => commit(
    edited.document,
    edit(edited.document, extent),
  ),
  _ => edited,
};
