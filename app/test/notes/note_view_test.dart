import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_view.dart';

void main() {
  group('a note first shows', () {
    test('as a list if it has items', () {
      expect(NoteView.first(hasItems: true, typing: false), NoteView.list);
      expect(NoteView.first(hasItems: true, typing: true), NoteView.list);
    });

    test('rendered for reading without items', () {
      expect(NoteView.first(hasItems: false, typing: false), NoteView.rendered);
    });

    test('as source to type a new note in', () {
      expect(NoteView.first(hasItems: false, typing: true), NoteView.text);
    });
  });
}
