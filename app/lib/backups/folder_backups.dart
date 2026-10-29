import 'package:truce_core/truce_core.dart';

import '../documents/document.dart';
import '../folders/base_folder.dart';
import '../folders/document_folder.dart';
import '../folders/folder_lookup.dart';

/// A backup and the folder its document is in.
typedef FolderBackup = ({DocumentFolder folder, Backup backup});

/// The backups of the documents [folders] show, newest first, each base
/// folder's from [backupsOf]. Backups of documents no folder shows (e.g.
/// after the user narrowed a folder) are left out; they age out unseen.
/// A base folder whose backups can't be read is left out.
Future<List<FolderBackup>> backupsShown(
  List<DocumentFolder> folders,
  FileBackups Function(BaseFolder base) backupsOf,
) async {
  final all = <FolderBackup>[];
  for (final base in {for (final folder in folders) folder.base}) {
    if (await backupsOf(base).list() case Ok(:final value)) {
      all.addAll([
        for (final backup in value)
          if (folders.folderOf(base.id, backup.filePath) case final folder?)
            (folder: folder, backup: backup),
      ]);
    }
  }
  return all..sort((a, b) => b.backup.savedAt.compareTo(a.backup.savedAt));
}

/// The backups of the document at [key], newest first, each base folder's
/// from [backupsOf]. None if none of [folders] shows it or its backups
/// can't be read.
Future<List<FolderBackup>> backupsOfDocument(
  DocumentKey key,
  List<DocumentFolder> folders,
  FileBackups Function(BaseFolder base) backupsOf,
) async {
  final folder = folders.folderOf(key.baseId, key.path);
  if (folder == null) return const [];
  return switch (await backupsOf(folder.base).listOf(key.path)) {
    Ok(:final value) => [
      for (final backup in value) (folder: folder, backup: backup),
    ],
    Err() => const [],
  };
}
