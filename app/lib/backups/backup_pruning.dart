import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../platform/app_activity.dart';
import '../settings/device_settings_controller.dart';
import '../storage/app_storage.dart';

final _pruningProvider = Provider<BackupPruning>(
  (ref) => BackupPruning(ref.watch(appStorageProvider).backupsRootPath),
);

/// Deletes old backups when the app comes into use, at most once a day,
/// and when the backup space set changes (see [BackupPruning]).
final backupPruningProvider = FutureProvider<void>((ref) async {
  final space = ref.watch(
    deviceSettingsProvider.select((s) => s.requireValue.backupSpace),
  );
  if (!ref.watch(appActiveProvider)) return;
  await ref.read(_pruningProvider).pruneIfDue(DateTime.now(), space);
});
