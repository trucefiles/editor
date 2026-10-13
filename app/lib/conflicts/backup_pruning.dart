import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../folders/folder_services.dart';
import '../folders/folders_controller.dart';

/// How long conflict backups are kept.
const backupRetention = Duration(days: 7);

/// Deletes conflict backups older than [backupRetention], once per app
/// run. Failing is harmless: the next run tries again.
final backupPruningProvider = FutureProvider<void>((ref) async {
  final folders = await ref.watch(foldersProvider.future);
  final olderThan = DateTime.now().subtract(backupRetention);
  for (final folder in folders) {
    await ref
        .read(folderServicesProvider(folder))
        .conflicts
        .pruneBackups(olderThan: olderThan);
  }
});
