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

  test('notePreview keeps file order and shows items as boxes', () {
    expect(
      notePreview('# T\nintro\n- [ ] a\n- [x] b\n  - [ ] c\nend'),
      'intro\n☐ a\n☑ b\n  ☐ c\nend',
    );
  });

  test('notePreview drops heading, quote and bullet markers', () {
    expect(
      notePreview('# T\n## Sub\n> quoted\n- one\n  * two'),
      'Sub\nquoted\n• one\n  • two',
    );
  });

  test('notePreview can leave out done items and count them', () {
    const text = '# T\n- [x] a\n  - [ ] sub\n- [ ] b\n- [x] c\nend';

    expect(notePreview(text, hideDone: true), '☐ b\nend\n+ 2 done');
    expect(notePreview(text, maxLines: 2, hideDone: true), '☐ b\n+ 2 done');
    expect(notePreview('# T\n- [ ] a', hideDone: true), '☐ a');
  });
}
