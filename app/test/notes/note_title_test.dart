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

    test('reads headings as the editor does: not in code, up to 3 spaces', () {
      expect(noteTitle('```\n# Code\n```\n   # Plan', path('a.md')), 'Plan');
      expect(noteTitle('    # Code', path('a.md')), 'a');
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
      notePreview('# T\nintro\n- [ ] a\n- [x] b\n  - [ ] c\n\nend'),
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
    const text = '# T\n- [x] a\n  - [ ] sub\n- [ ] b\n- [x] c\n\nend';

    expect(notePreview(text, hideDone: true), '☐ b\nend\n+ 2 done');
    expect(notePreview(text, maxLines: 2, hideDone: true), '☐ b\n+ 2 done');
    expect(notePreview('# T\n- [ ] a', hideDone: true), '☐ a');
  });

  test('noteTitleLine takes the first line as plain words', () {
    expect(noteTitleLine('\n  Milk and eggs \nmore'), 'Milk and eggs');
    expect(noteTitleLine('# Plan\n'), 'Plan');
    expect(noteTitleLine('- [ ] call Bob'), 'call Bob');
    expect(noteTitleLine('> - quoted'), 'quoted');
    expect(noteTitleLine('* one'), 'one');
    expect(noteTitleLine(' \n'), '');
  });
}
