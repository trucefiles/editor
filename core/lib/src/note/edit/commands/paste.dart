import '../../visible/formatting.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import 'split_block.dart';
import 'text_commands.dart';

/// Plain [text] pasted over [range] in [formatting]: literal, each line
/// break an Enter in the place the text has reached (new items in an
/// item, paragraphs elsewhere, lines in code); the caret after it.
Edited paste(
  ShownNote note,
  TextSelection range,
  String text,
  Formatting formatting,
) {
  final cleared = range.isCaret
      ? (note: note, selection: range)
      : commit(note, deleteRange(note, range));
  final lines = text.split(RegExp(r'\r\n?|\n'));
  return lines.indexed.fold(cleared, (edited, entry) {
    final (index, line) = entry;
    final split = index == 0
        ? edited
        : commit(edited.note, splitBlock(edited.note, _caret(edited)));
    return line.isEmpty
        ? split
        : commit(
            split.note,
            insertText(split.note, _caret(split), line, formatting),
          );
  });
}

Place _caret(Edited edited) => (edited.selection as TextSelection).extent;
