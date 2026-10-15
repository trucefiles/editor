import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/backups/backup_pruning.dart';
import 'package:truce_editor/platform/app_storage.dart';
import 'package:truce_editor/platform/device_id.dart';

import '../support.dart';

void main() {
  late AppStorage storage;

  setUp(() => storage = AppStorage(tempFolder().path));

  /// Writes a backup of `a.md` saved [age] ago into [folderId]'s backups.
  File backup(String folderId, Duration age) {
    final savedAt = DateTime.now().subtract(age).microsecondsSinceEpoch;
    return File('${storage.backupsPath(folderId)}/$savedAt.other/notes/a.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('backup');
  }

  Future<void> prune() async {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(backupPruningProvider.future);
  }

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

    await prune();

    expect(old.parent.parent.existsSync(), isFalse);
    expect(recent.parent.existsSync(), isTrue);
    expect(Directory(storage.backupsPath('current')).existsSync(), isTrue);
  });

  test('does nothing before the first backup', () async {
    await prune();
  });
}
