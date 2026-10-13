import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../folders/folder_services.dart';
import '../platform/app_storage.dart';

/// How long conflict backups are kept.
const backupRetention = Duration(days: 7);

/// Deletes conflict backups older than [backupRetention] in every backup
/// folder, also those of folders removed since, once per app run. Failing
/// is harmless: the next run tries again.
final backupPruningProvider = FutureProvider<void>((ref) async {
  final storage = ref.watch(appStorageProvider);
  final olderThan = DateTime.now().subtract(backupRetention);
  for (final path in await storage.allBackupsPaths()) {
    await conflictBackupsAt(path).prune(olderThan: olderThan);
  }
});
