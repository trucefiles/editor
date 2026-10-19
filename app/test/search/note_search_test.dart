import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/search/note_search.dart';

import '../support.dart';

const _folder = NoteFolder(
  id: 'f1',
  path: '/notes',
  name: 'Notes',
  color: Color(0xFF009688),
);

Note note(String name, String text) =>
    noteOf(_folder, text, name: name, modified: DateTime(2026));

void main() {
  final shopping = note('a.md', '# Shopping\n- [ ] Milk');
  final milk = note('b.md', '# Milk run\nshopping later');
  final other = note('c.md', '# Other\nnothing');
  final notes = [shopping, milk, other];

  test('finds every word, ignoring case', () {
    expect(searchNotes(notes, 'MILK shopping'), [shopping, milk]);
  });

  test('puts title matches first', () {
    expect(searchNotes(notes, 'milk'), [milk, shopping]);
  });

  test('finds a title taken from the file name', () {
    final named = note('Groceries.md', '- [ ] milk');

    expect(searchNotes([named], 'groceries'), [named]);
  });

  test('finds nothing for an empty query', () {
    expect(searchNotes(notes, '  '), isEmpty);
  });
}
