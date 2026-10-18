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

  test('ends in the extension given', () {
    expect(noteFileName('plan', extension: '.MD'), 'plan.MD');
    expect(noteFileName('plan', attempt: 2, extension: ''), 'plan 2');
  });

  test('splitFileName splits before the extension', () {
    expect(splitFileName('todo.md'), (base: 'todo', extension: '.md'));
    expect(splitFileName('a.b.md'), (base: 'a.b', extension: '.md'));
    expect(splitFileName('README'), (base: 'README', extension: ''));
    expect(splitFileName('.hidden'), (base: '.hidden', extension: ''));
  });

  test('isNamedAfter ignores an added number and the case', () {
    expect(isNamedAfter('Milk 2.md', 'Milk'), isTrue);
    expect(isNamedAfter('milk.md', 'Milk'), isTrue);
    expect(isNamedAfter('a b.md', 'a/b'), isTrue);
    expect(isNamedAfter('Milk 2.md', 'Eggs'), isFalse);
    expect(isNamedAfter('Milky.md', 'Milk'), isFalse);
  });
}
