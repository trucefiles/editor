import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  group('RelPath.parse', () {
    test('accepts relative paths', () {
      expect(RelPath.parse('todo.md')?.value, 'todo.md');
      expect(RelPath.parse('lists/todo.md')?.value, 'lists/todo.md');
    });

    test('rejects empty, absolute and dot paths', () {
      for (final raw in ['', '/todo.md', 'a//b', 'a/', './a', 'a/../b']) {
        expect(RelPath.parse(raw), isNull, reason: raw);
      }
    });
  });

  test('RelPath.name is the last segment', () {
    expect(RelPath.parse('lists/todo.md')!.name, 'todo.md');
    expect(RelPath.parse('todo.md')!.name, 'todo.md');
  });

  test('RelPath.parent is the folder path, null at the root', () {
    expect(RelPath.parse('a/b/c/todo.md')!.parent?.value, 'a/b/c');
    expect(RelPath.parse('lists/todo.md')!.parent?.value, 'lists');
    expect(RelPath.parse('todo.md')!.parent, isNull);
  });

  test('RelPath.sibling replaces the last segment', () {
    expect(
      RelPath.parse('lists/todo.md')!.sibling('done.md')?.value,
      'lists/done.md',
    );
    expect(RelPath.parse('todo.md')!.sibling('done.md')?.value, 'done.md');
    expect(RelPath.parse('todo.md')!.sibling('a/b'), isNull);
    expect(RelPath.parse('todo.md')!.sibling('..'), isNull);
  });
}
