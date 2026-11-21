import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  final start = DateTime.utc(2026, 11, 10);

  /// A backup of [file] in [folder], saved [hour] hours after the start,
  /// of [size] bytes.
  SizedBackup<String> backup(
    String file,
    int hour,
    int size, {
    String folder = 'docs',
    BackupKind kind = BackupKind.beforeEdit,
  }) => (
    folder: folder,
    backup: Backup.of(
      RelPath.parse(file)!,
      at: start.add(Duration(hours: hour)),
      kind: kind,
    ),
    size: size,
  );

  /// The [deleted] backups as file and hour.
  List<(String, int)> named(List<SizedBackup<String>> deleted) => [
    for (final (:backup, folder: _, size: _) in deleted)
      (backup.filePath.value, backup.savedAt.difference(start).inHours),
  ];

  test('within the limit, nothing goes', () {
    expect(
      overSpaceLimit([backup('a.md', 1, 50), backup('a.md', 2, 50)], 100),
      isEmpty,
    );
  });

  test("over the limit, the largest file's oldest backups go first, until "
      'within it', () {
    final backups = [
      backup('big.md', 1, 60),
      backup('big.md', 2, 60),
      backup('big.md', 3, 60),
      backup('small.md', 0, 10),
      backup('small.md', 4, 10),
    ];

    expect(named(overSpaceLimit(backups, 100)), [('big.md', 1), ('big.md', 2)]);
  });

  test('once the largest file shrank below another, that one gives up its '
      'oldest next', () {
    final backups = [
      backup('a.md', 1, 40),
      backup('a.md', 2, 40),
      backup('b.md', 3, 30),
      backup('b.md', 4, 30),
    ];

    expect(named(overSpaceLimit(backups, 90)), [('a.md', 1), ('b.md', 3)]);
  });

  test("a file's newest backup always stays, even over the limit", () {
    final backups = [
      backup('a.md', 1, 80),
      backup('a.md', 2, 80),
      backup('b.md', 3, 80),
    ];

    expect(named(overSpaceLimit(backups, 10)), [('a.md', 1)]);
  });

  test('both sides of the latest kept conflict stay, even over the limit', () {
    final backups = [
      backup('a.md', 1, 80),
      backup('a.md', 2, 80, kind: BackupKind.current),
      backup('a.md', 2, 80, kind: BackupKind.other),
    ];

    expect(named(overSpaceLimit(backups, 10)), [('a.md', 1)]);
  });

  test("a deleted file's backup stays, even once a newer one is at its "
      'path', () {
    final backups = [
      backup('a.md', 1, 80, kind: BackupKind.beforeDelete),
      backup('a.md', 2, 80),
      backup('a.md', 3, 80),
    ];

    expect(named(overSpaceLimit(backups, 10)), [('a.md', 2)]);
  });

  test("deleted files' backups don't count toward the limit", () {
    final backups = [
      backup('gone.jpg', 0, 500, kind: BackupKind.beforeDelete),
      backup('a.md', 1, 40),
      backup('a.md', 2, 40),
    ];

    expect(overSpaceLimit(backups, 100), isEmpty);
  });

  test('the same path in two folders is two files', () {
    final backups = [
      backup('a.md', 1, 50),
      backup('a.md', 2, 50, folder: 'work'),
    ];

    expect(overSpaceLimit(backups, 10), isEmpty);
  });
}
