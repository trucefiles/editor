import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../platform/app_activity.dart';
import '../storage/app_storage.dart';

/// Deletes backups older than [backupRetention] (see [pruneBackupsAt])
/// each time the app comes into use. Failing is harmless: the next time
/// tries again.
final backupPruningProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(appActiveProvider)) return;
  await pruneBackupsAt(
    ref.watch(appStorageProvider).backupsRootPath,
    olderThan: DateTime.now().subtract(backupRetention),
  );
});
