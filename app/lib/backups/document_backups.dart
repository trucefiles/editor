import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../documents/document.dart';
import '../folders/folders_controller.dart';
import '../sync_tool/folder_services.dart';
import 'all_backups.dart';

/// The backups of one document, newest first; read again each time they
/// are shown. None if its folder is gone or its backups can't be read.
final documentBackupsProvider = FutureProvider.autoDispose
    .family<List<FolderBackup>, DocumentKey>((ref, key) async {
      final folders = await ref.watch(foldersProvider.future);
      final folder = folders.where((f) => f.id == key.folderId).firstOrNull;
      if (folder == null) return const [];
      final backups = ref
          .watch(folderServicesProvider(folder.location))
          .backups;
      return switch (await backups.listOf(key.path)) {
        Ok(:final value) => [
          for (final backup in value) (folder: folder, backup: backup),
        ],
        Err() => const [],
      };
    });
