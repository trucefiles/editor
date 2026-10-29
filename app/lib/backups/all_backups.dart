import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/document_folder.dart';
import '../folders/folder_lookup.dart';
import '../folders/folders_controller.dart';
import '../sync_tool/base_folder_services.dart';

/// A backup and the folder its document is in.
typedef FolderBackup = ({DocumentFolder folder, Backup backup});

/// The backups of the documents the folders added on this device show,
/// newest first; read again each time they are shown. Backups of
/// documents no folder shows (e.g. after the user narrowed a folder) are
/// left out; they age out unseen. A base folder whose backups can't be
/// read is left out.
final allBackupsProvider = FutureProvider.autoDispose<List<FolderBackup>>((
  ref,
) async {
  final folders = await ref.watch(foldersProvider.future);
  final sources = [
    for (final base in {for (final folder in folders) folder.base})
      (base, ref.watch(baseFolderServicesProvider(base)).backups),
  ];
  final all = <FolderBackup>[];
  for (final (base, backups) in sources) {
    if (await backups.list() case Ok(:final value)) {
      all.addAll([
        for (final backup in value)
          if (folders.folderOf(base.id, backup.filePath) case final folder?)
            (folder: folder, backup: backup),
      ]);
    }
  }
  return all..sort((a, b) => b.backup.savedAt.compareTo(a.backup.savedAt));
});
