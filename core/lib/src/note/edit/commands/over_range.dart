import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import 'text_commands.dart';

/// [note] with the text in [range] removed, the caret where it was.
Edited cleared(ShownNote note, TextSelection range) => range.isCaret
    ? (note: note, selection: range)
    : commit(note, deleteRange(note, range));

/// [edit] made at the caret once the text in [range] is removed: a key
/// pressed over a selection.
Edited overRange(
  ShownNote note,
  TextSelection range,
  Edit Function(ShownNote note, Place at) edit,
) {
  final clear = cleared(note, range);
  return commit(clear.note, edit(clear.note, caretOf(clear)));
}

/// The caret [edited] leaves.
Place caretOf(Edited edited) => (edited.selection as TextSelection).extent;
