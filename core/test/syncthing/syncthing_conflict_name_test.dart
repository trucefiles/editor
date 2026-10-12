import 'package:test/test.dart';
import 'package:truce_core/src/syncthing/syncthing_conflict_name.dart';

void main() {
  test('parses a current conflict name', () {
    final name = SyncthingConflictName.parse(
      'todo.sync-conflict-20261003-134809-4I343AW.md',
    )!;

    expect(name.mainName, 'todo.md');
    expect(name.createdAt, DateTime(2026, 10, 3, 13, 48, 9));
  });

  test('parses names without device ID or extension', () {
    expect(
      SyncthingConflictName.parse('todo.sync-conflict-20151003-134809.md')
          ?.mainName,
      'todo.md',
    );
    expect(
      SyncthingConflictName.parse(
        'Makefile.sync-conflict-20261003-134809-4I343AW',
      )?.mainName,
      'Makefile',
    );
  });

  test('keeps dots inside the base name', () {
    expect(
      SyncthingConflictName.parse(
        'v1.2 plan.sync-conflict-20261003-134809-4I343AW.md',
      )?.mainName,
      'v1.2 plan.md',
    );
  });

  test('maps nested names to the innermost main file, newest marker', () {
    final name = SyncthingConflictName.parse(
      'todo.sync-conflict-20261003-134809-4I343AW'
      '.sync-conflict-20261004-080000-ABCDEFG.md',
    )!;

    expect(name.mainName, 'todo.md');
    expect(name.createdAt, DateTime(2026, 10, 4, 8));
  });

  test('rejects other names', () {
    for (final raw in [
      'todo.md',
      'todo.sync-conflict.md',
      'todo.sync-conflict-2026103-134809.md',
      'todo.sync-conflict-20261003-134809-4I343AW.notes.md',
      '.sync-conflict-20261003-134809-4I343AW',
    ]) {
      expect(SyncthingConflictName.parse(raw), isNull, reason: raw);
    }
  });
}
