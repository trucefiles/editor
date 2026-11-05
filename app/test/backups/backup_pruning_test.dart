import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/backups/backup_pruning.dart';
import 'package:truce_editor/platform/app_activity.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';

void main() {
  late AppStorage storage;

  setUp(() => storage = AppStorage(tempFolder().path));

  /// Writes a backup of `a.md` saved [age] ago into the backups of the folder [folder].
  File backup(String folder, Duration age) {
    final savedAt = DateTime.now().subtract(age).microsecondsSinceEpoch;
    return File(
      '${storage.backupsPath(folderId(folder))}/$savedAt.other/documents/a.md',
    )..writeCreatingFolders('backup');
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

  test('deletes old backups when the app comes into use, not again the '
      'same day', () async {
    final first = backup('current', const Duration(days: 8));
    final recent = backup('current', const Duration(days: 1));
    final container = pruning();
    await container.read(backupPruningProvider.future);
    expect(first.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
    final later = backup('current', const Duration(days: 8));
    final activity = container.read(appActiveProvider.notifier) as _Activity;

    activity.set(active: false);
    await container.read(backupPruningProvider.future);
    activity.set(active: true);
    await container.read(backupPruningProvider.future);

    expect(later.existsSync(), isTrue, reason: 'pruned today already');
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
