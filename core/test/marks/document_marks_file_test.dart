import 'dart:convert';

import 'package:test/test.dart';
import 'package:truce_core/src/marks/document_marks_file.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart' show bytesOf;

void main() {
  final changed = DateTime.utc(2026, 10, 13, 18, 40);

  test('round-trips marks, unmarked documents included', () {
    final marks = <String, StampedMark>{
      'b.md': (mark: const DocumentMark(color: 'teal'), changed: changed),
      'gone.md': (mark: DocumentMark.none, changed: changed),
    };

    expect(DocumentMarksFile.decode(DocumentMarksFile.encode(marks)), marks);
  });

  test('writes readable JSON sorted by name', () {
    final bytes = DocumentMarksFile.encode({
      'z.md': (mark: DocumentMark.none, changed: changed),
      'a.md': (mark: const DocumentMark(color: 'teal'), changed: changed),
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
      final decoded = DocumentMarksFile.decode(
        bytesOf(
          '{"todo.md": {"pinned": true, "color": "teal", "doneSection": false, '
          '"changed": "2026-10-13T18:40:00.000Z"}}',
        ),
      );

      expect(decoded, {
        'todo.md': (mark: const DocumentMark(color: 'teal'), changed: changed),
      });
    },
  );

  test('skips entries for documents in other directories', () {
    final decoded = DocumentMarksFile.decode(
      bytesOf(
        '{"lists/a.md": {"color": "teal", "changed": "2026-10-13T18:40:00Z"},'
        ' "..": {"color": "teal", "changed": "2026-10-13T18:40:00Z"}}',
      ),
    );

    expect(decoded, isEmpty);
  });

  test('skips a mark whose color is not a string', () {
    final decoded = DocumentMarksFile.decode(
      bytesOf('{"todo.md": {"color": 1, "changed": "2026-10-13T18:40:00Z"}}'),
    );

    expect(decoded, isEmpty);
  });

  test('reads a file that is not a JSON object as unreadable', () {
    expect(DocumentMarksFile.decode(bytesOf('[1, 2]')), isNull);
    expect(DocumentMarksFile.decode(bytesOf('{')), isNull);
  });
}
