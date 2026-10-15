import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/test_helpers.dart';

void main() {
  final at = DateTime.utc(2026, 10, 12, 15);
  final micros = at.microsecondsSinceEpoch;

  test('keeps the whole note path below the time and kind', () {
    final backup = Backup.of(
      path('lists/todo.md'),
      at: at,
      kind: BackupKind.beforeEdit,
    );

    expect(backup.storePath.value, '$micros.edit/lists/todo.md');
  });

  test('parses what it writes, for every kind', () {
    for (final kind in BackupKind.values) {
      final written = Backup.of(path('a/b/日本語 100%.md'), at: at, kind: kind);

      final parsed = Backup.parse(written.storePath)!;

      expect(parsed, written);
      expect(parsed.notePath, path('a/b/日本語 100%.md'));
      expect(parsed.savedAt, at);
      expect(parsed.kind, kind);
    }
  });

  test('keeps a long path whole', () {
    final folders = List.filled(40, '日本語').join('/');

    final backup = Backup.of(
      path('$folders/todo.md'),
      at: at,
      kind: BackupKind.other,
    );

    expect(Backup.parse(backup.storePath)!.notePath, path('$folders/todo.md'));
  });

  test('parses nothing else', () {
    for (final raw in [
      'todo.md',
      '$micros.edit',
      '$micros/todo.md',
      '$micros.unknown/todo.md',
      'x.edit/todo.md',
      '$micros.edit.x/todo.md',
      '$micros.current.todo.md',
    ]) {
      expect(Backup.parse(path(raw)), isNull, reason: raw);
    }
  });

  test('tells when a file was saved as a backup, in any layout', () {
    expect(Backup.savedAtOf(path('$micros.edit/todo.md')), at);
    expect(Backup.savedAtOf(path('$micros.current.lists%2Ftodo.md')), at);
    expect(Backup.savedAtOf(path('not-a-backup.txt')), isNull);
  });
}
