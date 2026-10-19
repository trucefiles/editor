import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_mode.dart';

void main() {
  group('a note first shows', () {
    test('in Visual edit if it has checkboxes', () {
      expect(
        NoteMode.first(hasCheckboxes: true, typing: false),
        NoteMode.visual,
      );
      expect(
        NoteMode.first(hasCheckboxes: true, typing: true),
        NoteMode.visual,
      );
    });

    test('in Read without checkboxes', () {
      expect(
        NoteMode.first(hasCheckboxes: false, typing: false),
        NoteMode.read,
      );
    });

    test('in Visual edit to type a new note in', () {
      expect(
        NoteMode.first(hasCheckboxes: false, typing: true),
        NoteMode.visual,
      );
    });
  });
}
