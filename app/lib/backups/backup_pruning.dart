import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../storage/app_storage.dart';
import '../sync_tool/syncthing/syncthing_wiring.dart';

/// How long backups are kept.
const backupRetention = Duration(days: 7);

/// Deletes backups older than [backupRetention] in every backup
/// folder, also those of folders removed since, once per app run, and the
/// folders they leave empty (only old ones: new backups may be on their
/// way into a new folder). Failing is harmless: the next run tries again.
final backupPruningProvider = FutureProvider<void>((ref) async {
  final storage = ref.watch(appStorageProvider);
  final olderThan = DateTime.now().subtract(backupRetention);
  for (final path in await storage.allBackupsPaths()) {
    await fileBackupsAt(path).prune(olderThan: olderThan);
    await storage.removeEmptyFolders(
      path,
      isStale: (name) =>
          Backup.savedAtOfFolder(name)?.isBefore(olderThan) ?? false,
    );
  }
});
