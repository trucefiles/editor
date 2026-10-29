import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../documents/document.dart';
import '../folders/folder_lookup.dart';
import '../folders/folders_controller.dart';
import '../sync_tool/base_folder_services.dart';
import 'all_backups.dart';

/// The backups of one document, newest first; read again each time they
/// are shown. None if no folder shows it or its backups can't be read.
final documentBackupsProvider = FutureProvider.autoDispose
    .family<List<FolderBackup>, DocumentKey>((ref, key) async {
      final folders = await ref.watch(loadedFoldersProvider.future);
      final folder = folders.folderOf(key.baseId, key.path);
      if (folder == null) return const [];
      final backups = ref
          .watch(baseFolderServicesProvider(folder.base))
          .backups;
      return switch (await backups.listOf(key.path)) {
        Ok(:final value) => [
          for (final backup in value) (folder: folder, backup: backup),
        ],
        Err() => const [],
      };
    });
