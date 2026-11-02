import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../folders/folders_controller.dart';
import '../folders/open_folders_wiring.dart';

/// The backups of one file (see [backupsOfFile]); read again each
/// time they are shown.
final fileBackupsProvider = FutureProvider.autoDispose
    .family<List<FolderBackup>, FileKey>((ref, key) async {
      // Built again as the list changes; none if it can't be read.
      ref.watch(folderListStateProvider);
      final open = ref.watch(openFoldersProvider);
      return backupsOfFile(
        key,
        await settledFolders(ref.read(folderListOwnerProvider)),
        (folder) => open.servicesOf(folder.id).backups,
      );
    });
