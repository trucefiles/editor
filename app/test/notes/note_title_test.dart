import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_title.dart';

import '../support.dart';

void main() {
  group('noteTitle', () {
    test('takes the first level-1 heading', () {
      expect(
        noteTitle('intro\n## Sub\n# Shopping \n# Later', path('a.md')),
        'Shopping',
      );
    });

    test('falls back to the file name without extension', () {
      expect(
        noteTitle('## Sub\ntext', path('lists/Groceries.md')),
        'Groceries',
      );
    });
  });

  test('notePreview skips the title and empty lines', () {
    expect(
      notePreview('# T\n\nfirst\n\nsecond\nthird', maxLines: 2),
      'first\nsecond',
    );
  });
}
