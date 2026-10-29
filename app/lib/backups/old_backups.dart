import 'package:truce_core/truce_core.dart';

import '../storage/app_storage.dart';

/// Deletes the backups saved before [olderThan] in every backup folder of
/// [storage], also those of folders removed since, and the folders they
/// leave empty (only old ones: new backups may be on their way into a new
/// folder).
Future<void> pruneOldBackups(
  AppStorage storage, {
  required DateTime olderThan,
}) async {
  for (final path in await storage.allBackupsPaths()) {
    await fileBackupsAt(path).prune(olderThan: olderThan);
    await storage.removeEmptyFolders(
      path,
      isStale: (name) =>
          Backup.savedAtOfFolder(name)?.isBefore(olderThan) ?? false,
    );
  }
}
