import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/syncthing_folder_services.dart';
import '../platform/app_storage.dart';

/// How long note backups are kept.
const backupRetention = Duration(days: 7);

/// Deletes note backups older than [backupRetention] in every backup
/// folder, also those of folders removed since, once per app run, and the
/// folders they leave empty (only old ones: new backups may be on their
/// way into a new folder). Failing is harmless: the next run tries again.
final backupPruningProvider = FutureProvider<void>((ref) async {
  final storage = ref.watch(appStorageProvider);
  final olderThan = DateTime.now().subtract(backupRetention);
  for (final path in await storage.allBackupsPaths()) {
    await noteBackupsAt(path).prune(olderThan: olderThan);
    await storage.removeEmptyFolders(
      path,
      isStale: (name) => switch (RelPath.parse(name)) {
        final folder? => Backup.savedAtOf(folder)?.isBefore(olderThan) ?? false,
        null => false,
      },
    );
  }
});
