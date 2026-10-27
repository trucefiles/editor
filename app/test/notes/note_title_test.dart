import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_title.dart';

import '../support.dart';

// How titles and first lines are read is tested in the markdown
// package (`DocumentSummary`); here only what the app adds.
void main() {
  test('noteTitle takes the first level-1 heading', () {
    expect(
      noteTitle('intro\n## Sub\n# Shopping \n# Later', path('a.md')),
      'Shopping',
    );
  });

  test('noteTitle falls back to the file name without extension', () {
    expect(noteTitle('## Sub\ntext', path('lists/Groceries.md')), 'Groceries');
  });

  test('noteTitleLine takes the first line as plain words', () {
    expect(noteTitleLine('\n  Milk and eggs \nmore'), 'Milk and eggs');
    expect(noteTitleLine(' \n'), '');
  });
}
