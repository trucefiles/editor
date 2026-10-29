import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../folders/folder_list_owner.dart';
import '../folders/folders_controller.dart';
import '../sync_tool/base_folder_wiring.dart';
import 'folder_backups.dart';

/// The backups of the documents the folders added on this device show
/// (see [backupsShown]); read again each time they are shown.
final allBackupsProvider = FutureProvider.autoDispose<List<FolderBackup>>((
  ref,
) async {
  // Built again as the list changes; none if it can't be read.
  ref.watch(folderListStateProvider);
  final stacks = ref.watch(baseFolderStacksProvider);
  return backupsShown(
    await settledFolders(ref.read(folderListOwnerProvider)),
    (base) => stacks.servicesOf(base).backups,
  );
});
