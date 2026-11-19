import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late String root;

  setUp(() => root = tempFolder().path);

  /// Writes a backup of [file] saved [age] ago into the backup folder
  /// [folder], [size] bytes long.
  File backup(
    String folder,
    Duration age, {
    String file = 'documents/a.md',
    int size = 6,
  }) {
    final savedAt = DateTime.now().subtract(age).microsecondsSinceEpoch;
    return File('$root/$folder/$savedAt.other/$file')
      ..createSync(recursive: true)
      ..writeAsStringSync('x' * size);
  }

  Future<void> prune() => pruneBackupsAt(
    root,
    olderThan: DateTime.now().subtract(const Duration(days: 7)),
    counts: _every,
  );

  test('deletes old backups of every folder, removed ones too', () async {
    final old = backup('current', const Duration(days: 8));
    final oldOfRemoved = backup('removed', const Duration(days: 8));
    final recent = backup('current', const Duration(days: 1));

    await prune();

    expect(old.existsSync(), isFalse);
    expect(oldOfRemoved.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
  });

  test('removes the folders old backups leave empty', () async {
    final old = backup('current', const Duration(days: 8));
    final recent = backup('current', const Duration(days: 1));
    // A backup on its way: its folder is made, its file not yet.
    final micros = DateTime.now().microsecondsSinceEpoch;
    final fresh = Directory('$root/current/$micros.edit/documents')
      ..createSync(recursive: true);

    await prune();

    expect(old.parent.parent.existsSync(), isFalse);
    expect(recent.parent.existsSync(), isTrue);
    expect(fresh.existsSync(), isTrue);
    expect(Directory('$root/current').existsSync(), isTrue);
  });

  test('over the space limit, the largest file gives up its oldest '
      'backups first, in every folder, and their folders go', () async {
    final oldest = backup('current', const Duration(hours: 3), size: 60);
    final older = backup('current', const Duration(hours: 2), size: 60);
    final newest = backup('current', const Duration(hours: 1), size: 60);
    final other = backup(
      'removed',
      const Duration(hours: 4),
      file: 'b.md',
      size: 10,
    );

    await pruneBackupsAt(
      root,
      olderThan: DateTime.now().subtract(const Duration(days: 7)),
      counts: _every,
      spaceLimit: 100,
    );

    expect(oldest.existsSync(), isFalse);
    expect(older.existsSync(), isFalse);
    expect(oldest.parent.parent.existsSync(), isFalse, reason: 'empty');
    expect(newest.existsSync(), isTrue);
    expect(other.existsSync(), isTrue);
  });

  test('backups of files it does not count never push others out', () async {
    final older = backup('current', const Duration(hours: 2), size: 60);
    final newest = backup('current', const Duration(hours: 1), size: 30);
    final apart = backup(
      'current',
      const Duration(hours: 3),
      file: 'kept/big.png',
      size: 500,
    );

    await pruneBackupsAt(
      root,
      olderThan: DateTime.now().subtract(const Duration(days: 7)),
      counts: (file) => !file.value.startsWith('kept/'),
      spaceLimit: 100,
    );

    expect(older.existsSync(), isTrue);
    expect(newest.existsSync(), isTrue);
    expect(apart.existsSync(), isTrue);
  });

  test('does nothing before the first backup', () async {
    await pruneBackupsAt(
      '$root/none',
      olderThan: DateTime.now(),
      counts: _every,
    );

    expect(Directory('$root/none').existsSync(), isFalse);
  });
}

bool _every(RelPath file) => true;
