import '../../visible/formatting.dart';
import 'selection.dart';
import 'shown_note.dart';

/// The formatting text typed at [at] takes once the caret moved there:
/// its left neighbor's, at a text's start the following character's.
/// A link goes on only between two of its characters, so typing at a
/// link's edge never extends it.
Formatting typingStyleAt(ShownNote note, Place at) {
  final text = note.textOf(at.slot);
  final offset = at.offset;
  if (text.text.isEmpty) return Formatting.plain;
  final neighbor = text.formattingAt(offset > 0 ? offset - 1 : 0);
  final inLink =
      offset > 0 &&
      offset < text.length &&
      neighbor.link != null &&
      identical(neighbor.link, text.formattingAt(offset).link);
  return inLink ? neighbor : neighbor.withLink(null);
}
