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
) {
  final clear = cleared(document, range);
  return commit(clear.document, edit(clear.document, caretOf(clear)));
}

/// The caret [edited] leaves.
Place caretOf(Edited edited) => (edited.selection as TextSelection).extent;
