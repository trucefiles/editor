import '../../visible/formatting.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import 'over_range.dart';
import 'split_block.dart';
import 'text_commands.dart';

/// Plain [text] pasted over [range] in [formatting]: literal, each line
/// break an Enter in the place the text has reached (new items in an
/// item, paragraphs elsewhere, lines in code); the caret after it.
Edited paste(
  ShownDocument document,
  TextSelection range,
  String text,
  Formatting formatting,
) {
  final lines = text.split(RegExp(r'\r\n?|\n'));
  return lines.indexed.fold(cleared(document, range), (edited, entry) {
    final (index, line) = entry;
    final split = index == 0 ? edited : atCaret(edited, splitBlock);
    return line.isEmpty
        ? split
        : atCaret(
            split,
            (document, at) => insertText(document, at, line, formatting),
          );
  });
}
