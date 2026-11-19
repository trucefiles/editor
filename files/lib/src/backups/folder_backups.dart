import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../listed_file.dart';

/// A backup and the folder its file is in.
typedef FolderBackup = ({Folder folder, Backup backup});

/// The backups of the files of [folders] the app [shows], newest first,
/// each folder's from [backupsOf]; backups of any other file (e.g. an
/// image the app keeps) are left out. A folder whose backups can't be
/// read is left out.
Future<List<FolderBackup>> backupsShown(
  List<Folder> folders,
  FileBackups Function(Folder folder) backupsOf, {
  required bool Function(RelPath file) shows,
}) async {
  final all = <FolderBackup>[];
  for (final folder in folders) {
    if (await backupsOf(folder).list() case Ok(:final value)) {
      all.addAll([
        for (final backup in value)
          if (shows(backup.filePath)) (folder: folder, backup: backup),
      ]);
    }
  }
  return all..sort((a, b) => b.backup.savedAt.compareTo(a.backup.savedAt));
}

/// The backups of the file at [key], newest first, from [backupsOf]. None
/// if its folder is not one of [folders] or its backups can't be read.
Future<List<FolderBackup>> backupsOfFile(
  FileKey key,
  List<Folder> folders,
  FileBackups Function(Folder folder) backupsOf,
) async {
  final folder = folders.byId(key.folder);
  if (folder == null) return const [];
  return switch (await backupsOf(folder).listOf(key.path)) {
    Ok(:final value) => [
      for (final backup in value) (folder: folder, backup: backup),
    ],
    Err() => const [],
  };
}
