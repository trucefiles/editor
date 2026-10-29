import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../documents/document.dart';
import '../folders/folder_list_owner.dart';
import '../folders/folders_controller.dart';
import '../sync_tool/base_folder_wiring.dart';
import 'folder_backups.dart';

/// The backups of one document (see [backupsOfDocument]); read again each
/// time they are shown.
final documentBackupsProvider = FutureProvider.autoDispose
    .family<List<FolderBackup>, DocumentKey>((ref, key) async {
      // Built again as the list changes; none if it can't be read.
      ref.watch(folderListStateProvider);
      final stacks = ref.watch(baseFolderStacksProvider);
      return backupsOfDocument(
        key,
        await settledFolders(ref.read(folderListOwnerProvider)),
        (base) => stacks.servicesOf(base).backups,
      );
    });
