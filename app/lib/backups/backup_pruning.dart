import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/app_activity.dart';
import '../storage/app_storage.dart';
import 'backup_retention.dart';
import 'old_backups.dart';

/// Deletes backups older than [backupRetention] (see [pruneOldBackups])
/// each time the app comes into use. Failing is harmless: the next time
/// tries again.
final backupPruningProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(appActiveProvider)) return;
  await pruneOldBackups(
    ref.watch(appStorageProvider),
    olderThan: DateTime.now().subtract(backupRetention),
  );
});
