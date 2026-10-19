import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_mode.dart';

void main() {
  group('a note first shows', () {
    test('in Visual edit if it has items', () {
      expect(NoteMode.first(hasItems: true, typing: false), NoteMode.visual);
      expect(NoteMode.first(hasItems: true, typing: true), NoteMode.visual);
    });

    test('in Read without items', () {
      expect(NoteMode.first(hasItems: false, typing: false), NoteMode.read);
    });

    test('in Visual edit to type a new note in', () {
      expect(NoteMode.first(hasItems: false, typing: true), NoteMode.visual);
    });
  });
}
