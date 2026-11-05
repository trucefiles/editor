import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../platform/app_activity.dart';
import '../storage/app_storage.dart';

final _pruningProvider = Provider<BackupPruning>(
  (ref) => BackupPruning(ref.watch(appStorageProvider).backupsRootPath),
);

/// Deletes old backups when the app comes into use, at most once a day
/// (see [BackupPruning]).
final backupPruningProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(appActiveProvider)) return;
  await ref.read(_pruningProvider).pruneIfDue(DateTime.now());
});
