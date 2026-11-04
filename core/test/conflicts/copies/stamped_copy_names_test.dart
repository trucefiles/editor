import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  final names = StampedCopyNames('my-copy');

  test('a copy name reads back as its main file and time', () {
    final at = DateTime(2026, 10, 3, 13, 48, 9);
    final name = names.format('todo.md', at);
    expect(name, 'todo.my-copy-20261003-134809.md');
    expect(names.parse(name), (mainName: 'todo.md', createdAt: at));
    expect(names.parse(names.format('notes', at))?.mainName, 'notes');
  });

  test('other names are no copies', () {
    for (final name in [
      'todo.md',
      'todo.other-20261003-134809.md',
      '.my-copy-20261003-134809.md',
      'todo.my-copy-2026103-134809.md',
    ]) {
      expect(names.parse(name), isNull, reason: name);
    }
  });
}
