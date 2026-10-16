import 'dart:convert';

import 'package:test/test.dart';
import 'package:truce_core/src/marks/note_marks_file.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  final changed = DateTime.utc(2026, 10, 13, 18, 40);

  test('round-trips marks, unmarked notes included', () {
    final marks = <RelPath, StampedMark>{
      path('a/b.md'): (mark: const NoteMark(color: 'teal'), changed: changed),
      path('gone.md'): (mark: NoteMark.none, changed: changed),
    };

    expect(NoteMarksFile.decode(NoteMarksFile.encode(marks)), marks);
  });

  test('writes readable JSON sorted by path', () {
    final bytes = NoteMarksFile.encode({
      path('z.md'): (mark: NoteMark.none, changed: changed),
      path('a.md'): (mark: const NoteMark(color: 'teal'), changed: changed),
    });

    expect(utf8.decode(bytes), '''
{
  "a.md": {
    "color": "teal",
    "changed": "2026-10-13T18:40:00.000Z"
  },
  "z.md": {
    "color": null,
    "changed": "2026-10-13T18:40:00.000Z"
  }
}
''');
  });

  test(
    'reads marks of older versions, ignoring their pin and Done section',
    () {
      final decoded = NoteMarksFile.decode(
        bytesOf(
          '{"todo.md": {"pinned": true, "color": "teal", "doneSection": false, '
          '"changed": "2026-10-13T18:40:00.000Z"}}',
        ),
      );

      expect(decoded, {
        path('todo.md'): (
          mark: const NoteMark(color: 'teal'),
          changed: changed,
        ),
      });
    },
  );

  test('skips a mark whose color is not a string', () {
    final decoded = NoteMarksFile.decode(
      bytesOf('{"todo.md": {"color": 1, "changed": "2026-10-13T18:40:00Z"}}'),
    );

    expect(decoded, isEmpty);
  });

  test('reads a file that is not a JSON object as unreadable', () {
    expect(NoteMarksFile.decode(bytesOf('[1, 2]')), isNull);
    expect(NoteMarksFile.decode(bytesOf('{')), isNull);
  });
}
