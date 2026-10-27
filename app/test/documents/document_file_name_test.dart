import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document_file_name.dart';

void main() {
  test('uses the title and .md', () {
    expect(documentFileName('Shopping list'), 'Shopping list.md');
  });

  test('numbers later attempts', () {
    expect(documentFileName('Shopping', attempt: 3), 'Shopping 3.md');
  });

  test('replaces unsafe characters and collapses spaces', () {
    expect(documentFileName('a/b: c?  d'), 'a b c d.md');
  });

  test('drops leading and trailing dots', () {
    expect(documentFileName('..hidden.. '), 'hidden.md');
  });

  test('falls back to Untitled', () {
    expect(documentFileName(' /?. '), 'Untitled.md');
  });

  test('limits the length without splitting characters', () {
    expect(documentFileName('a' * 100), '${'a' * 80}.md');
  });

  test('leaves room for a conflict copy in 255 bytes', () {
    // 4 bytes each: 50 fit in 200 bytes.
    expect(documentFileName('😀' * 100), '${'😀' * 50}.md');
  });

  test('never cuts a character made of several code points', () {
    // A family emoji: 7 code points, 25 bytes. After 5 bytes of `a`, 7
    // fit in 200 bytes; cut by code points, part of an 8th would stay.
    const family = '👨‍👩‍👧‍👦';
    expect(documentFileName('aaaaa${family * 10}'), 'aaaaa${family * 7}.md');
  });

  test('counts a character made of several code points as one', () {
    // e with a combining accent: 2 code points, 3 bytes; 66 fit in 200.
    const accented = 'e\u0301';
    expect(documentFileName(accented * 100), '${accented * 66}.md');
  });

  test('ends in the extension given', () {
    expect(documentFileName('plan', extension: '.MD'), 'plan.MD');
    expect(documentFileName('plan', attempt: 2, extension: ''), 'plan 2');
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
