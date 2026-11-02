import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late String root;

  setUp(() => root = tempFolder().path);

  /// Writes a backup of `a.md` saved [age] ago into the backup folder
  /// [folder].
  File backup(String folder, Duration age) {
    final savedAt = DateTime.now().subtract(age).microsecondsSinceEpoch;
    return File('$root/$folder/$savedAt.other/documents/a.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('backup');
  }

  Future<void> prune() => pruneBackupsAt(
    root,
    olderThan: DateTime.now().subtract(const Duration(days: 7)),
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

  test('does nothing before the first backup', () async {
    await pruneBackupsAt('$root/none', olderThan: DateTime.now());

    expect(Directory('$root/none').existsSync(), isFalse);
  });
}
