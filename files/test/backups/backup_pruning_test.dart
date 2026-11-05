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

  /// Writes a backup saved [age] before [start].
  File backup(Duration age) {
    final savedAt = start.subtract(age).microsecondsSinceEpoch;
    return File('$root/folder/$savedAt.other/documents/a.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('backup');
  }

  test('prunes the first time, then not again within a day', () async {
    final old = backup(const Duration(days: 8));
    await pruning.pruneIfDue(start);
    expect(old.existsSync(), isFalse);

    final later = backup(const Duration(days: 8));
    await pruning.pruneIfDue(start.add(const Duration(hours: 23)));

    expect(later.existsSync(), isTrue);
  });

  test('prunes again a day after the last time', () async {
    await pruning.pruneIfDue(start);
    final aged = backup(const Duration(days: 6, hours: 12));

    await pruning.pruneIfDue(start.add(BackupPruning.every));

    expect(aged.existsSync(), isFalse, reason: 'older than kept by then');
  });
}
