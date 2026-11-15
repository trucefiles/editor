import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late String root;
  late BackupPruning pruning;
  final start = DateTime(2026, 11, 5, 9);

  setUp(() {
    root = tempFolder().path;
    pruning = BackupPruning(root);
  });

  /// Writes a backup saved [age] before [start], [megabytes] large.
  File backup(Duration age, {int megabytes = 0}) {
    final savedAt = start.subtract(age).microsecondsSinceEpoch;
    return File('$root/folder/$savedAt.other/documents/a.md')
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(megabytes * 1000 * 1000 + 6, 0));
  }

  test('prunes the first time, then not again within a day', () async {
    final old = backup(const Duration(days: 8));
    await pruning.pruneIfDue(start, BackupSpace.standard);
    expect(old.existsSync(), isFalse);

    final later = backup(const Duration(days: 8));
    await pruning.pruneIfDue(
      start.add(const Duration(hours: 23)),
      BackupSpace.standard,
    );

    expect(later.existsSync(), isTrue);
  });

  test('prunes again a day after the last time', () async {
    await pruning.pruneIfDue(start, BackupSpace.standard);
    final aged = backup(const Duration(days: 6, hours: 12));

    await pruning.pruneIfDue(
      start.add(BackupPruning.every),
      BackupSpace.standard,
    );

    expect(aged.existsSync(), isFalse, reason: 'older than kept by then');
  });

  test('prunes again within the day once the space set changes, to the '
      'new space', () async {
    await pruning.pruneIfDue(start, BackupSpace.noLimit);
    final older = backup(const Duration(hours: 2), megabytes: 30);
    final newer = backup(const Duration(hours: 1), megabytes: 30);

    await pruning.pruneIfDue(start, BackupSpace.mb50);

    expect(older.existsSync(), isFalse);
    expect(newer.existsSync(), isTrue);
  });
}
