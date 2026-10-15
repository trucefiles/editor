import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folder_services.dart';
import '../folders/folders_controller.dart';
import '../folders/note_folder.dart';

/// A backup and the folder its note is in.
typedef FolderBackup = ({NoteFolder folder, Backup backup});

/// The backups of every folder added on this device, newest first; read
/// again each time they are shown. A folder whose backups can't be read is
/// left out.
final allBackupsProvider = FutureProvider.autoDispose<List<FolderBackup>>((
  ref,
) async {
  final folders = await ref.watch(foldersProvider.future);
  final sources = [
    for (final folder in folders)
      (folder, ref.watch(folderServicesProvider(folder.location)).backups),
  ];
  final all = <FolderBackup>[];
  for (final (folder, backups) in sources) {
    if (await backups.list() case Ok(:final value)) {
      all.addAll([
        for (final backup in value) (folder: folder, backup: backup),
      ]);
    }
  }
  return all..sort((a, b) => b.backup.savedAt.compareTo(a.backup.savedAt));
});
