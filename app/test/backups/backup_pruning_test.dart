import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/backups/backup_pruning.dart';
import 'package:truce_editor/platform/app_activity.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

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

  ProviderContainer pruning() {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        appActiveProvider.overrideWith(_Activity.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(backupPruningProvider, (_, _) {});
    return container;
  }

  Future<void> prune() => pruning().read(backupPruningProvider.future);

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
    final fresh = Directory(
      '${storage.backupsPath('current')}/$micros.edit/notes',
    )..createSync(recursive: true);

    await prune();

    expect(old.parent.parent.existsSync(), isFalse);
    expect(recent.parent.existsSync(), isTrue);
    expect(fresh.existsSync(), isTrue);
    expect(Directory(storage.backupsPath('current')).existsSync(), isTrue);
  });

  test('deletes old backups again each time the app comes into use', () async {
    final container = pruning();
    await container.read(backupPruningProvider.future);
    final old = backup('current', const Duration(days: 8));
    final activity = container.read(appActiveProvider.notifier) as _Activity;

    activity.set(active: false);
    await container.read(backupPruningProvider.future);
    expect(old.existsSync(), isTrue);

    activity.set(active: true);
    await container.read(backupPruningProvider.future);
    expect(old.existsSync(), isFalse);
  });

  test('does nothing before the first backup', () async {
    await prune();
  });
}

class _Activity extends AppActivity {
  @override
  bool build() => true;

  void set({required bool active}) => state = active;
}
