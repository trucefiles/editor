import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/edit/shown/typing_style.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/visible/formatting.dart';

/// The typing style at [offset] of [text]'s first row.
Formatting _styleAt(String text, int offset) {
  final note = ShownNote(NoteTree.read(text));
  return typingStyleAt(note, Place((note.rows.first as TextRow).slot, offset));
}

void main() {
  test('follows the left neighbor', () {
    expect(_styleAt('**ab**c', 2).formats, {TextFormat.strong});
    expect(_styleAt('**ab**c', 3).formats, isEmpty);
  });

  test('at a text\'s start, follows the following character', () {
    expect(_styleAt('*a*b', 0).formats, {TextFormat.emphasis});
  });

  test('is plain in an empty text place', () {
    expect(_styleAt('', 0).formats, isEmpty);
  });

  test('stays in a link only between its characters', () {
    expect(_styleAt('[ab](u) c', 1).link?.destination, 'u');
    expect(_styleAt('[ab](u) c', 2).link, isNull);
    expect(_styleAt('[ab](u)', 0).link, isNull);
    expect(_styleAt('[**ab**](u)', 2).formats, {TextFormat.strong});
  });
}
