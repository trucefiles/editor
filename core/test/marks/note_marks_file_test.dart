import 'dart:convert';

import 'package:test/test.dart';
import 'package:truce_core/src/marks/note_marks_file.dart';
import 'package:truce_core/testing.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  final changed = DateTime.utc(2026, 10, 13, 18, 40);

  test('round-trips marks, unmarked notes included', () {
    final marks = <RelPath, StampedMark>{
      path('todo.md'): (mark: const NoteMark(pinned: true), changed: changed),
      path('a/b.md'): (mark: const NoteMark(color: 'teal'), changed: changed),
      path('gone.md'): (mark: NoteMark.none, changed: changed),
    };

    expect(NoteMarksFile.decode(NoteMarksFile.encode(marks)), marks);
  });

  test('writes readable JSON sorted by path', () {
    final bytes = NoteMarksFile.encode({
      path('z.md'): (mark: NoteMark.none, changed: changed),
      path('a.md'): (mark: const NoteMark(pinned: true), changed: changed),
    });

    expect(utf8.decode(bytes), '''
{
  "a.md": {
    "pinned": true,
    "color": null,
    "changed": "2026-10-13T18:40:00.000Z"
  },
  "z.md": {
    "pinned": false,
    "color": null,
    "changed": "2026-10-13T18:40:00.000Z"
  }
}
''');
  });

  test('reads a file that is not a JSON object as unreadable', () {
    expect(NoteMarksFile.decode(bytesOf('[1, 2]')), isNull);
    expect(NoteMarksFile.decode(bytesOf('{')), isNull);
  });
}
