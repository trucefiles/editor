import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_file_name.dart';

void main() {
  test('uses the title and .md', () {
    expect(noteFileName('Shopping list'), 'Shopping list.md');
  });

  test('numbers later attempts', () {
    expect(noteFileName('Shopping', attempt: 3), 'Shopping 3.md');
  });

  test('replaces unsafe characters and collapses spaces', () {
    expect(noteFileName('a/b: c?  d'), 'a b c d.md');
  });

  test('drops leading and trailing dots', () {
    expect(noteFileName('..hidden.. '), 'hidden.md');
  });

  test('falls back to Untitled', () {
    expect(noteFileName(' /?. '), 'Untitled.md');
  });

  test('limits the length without splitting characters', () {
    expect(noteFileName('a' * 100), '${'a' * 80}.md');
  });

  test('leaves room for a conflict copy in 255 bytes', () {
    // 4 bytes each: 50 fit in 200 bytes.
    expect(noteFileName('😀' * 100), '${'😀' * 50}.md');
  });
}
