import 'dart:io';

import '../backups/backup.dart';
import 'file_backups_at.dart';

/// Deletes the backups saved before [olderThan] in every backup folder
/// right below [root] (one per folder of the app, also of folders removed
/// since), and the folders they leave empty. Only old folders go: a new
/// backup may be on its way into a new one. Failing is harmless: what
/// can't be read or removed stays for the next time.
Future<void> pruneBackupsAt(String root, {required DateTime olderThan}) async {
  for (final folder in await _foldersIn(Directory(root))) {
    await fileBackupsAt(folder.path).prune(olderThan: olderThan);
    await _removeEmpty(
      await _foldersIn(folder),
      isStale: (name) =>
          Backup.savedAtOfFolder(name)?.isBefore(olderThan) ?? false,
    );
  }
}

/// The folders right below [folder]; none if it can't be read.
Future<List<Directory>> _foldersIn(Directory folder) async {
  try {
    return await folder
        .list(followLinks: false)
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
  } on FileSystemException {
    return const [];
  }
}

/// Removes those of [folders] whose name [isStale] accepts, and the
/// folders inside them, where they are empty.
Future<void> _removeEmpty(
  List<Directory> folders, {
  required bool Function(String name) isStale,
}) async {
  final stale = [
    for (final folder in folders)
      if (isStale(folder.uri.pathSegments.lastWhere((s) => s.isNotEmpty)))
        folder,
  ];
  final all =
      [...stale, for (final folder in stale) ...await _foldersInside(folder)]
        // Deepest first, so a folder holding only empty folders goes too.
        ..sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final folder in all) {
    try {
      // Not recursive: fails for a folder that still holds anything.
      await folder.delete();
    } on FileSystemException {
      continue;
    }
  }
}

/// Every folder inside [folder], at any depth; none if it can't be read.
Future<List<Directory>> _foldersInside(Directory folder) async {
  try {
    return await folder
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
  } on FileSystemException {
    return const [];
  }
}
