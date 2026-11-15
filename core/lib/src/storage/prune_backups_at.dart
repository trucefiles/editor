import 'dart:io';

import '../backups/backup.dart';
import '../backups/backup_space.dart';
import '../common/result.dart';
import 'file_backups_at.dart';

/// Deletes the backups saved before [olderThan] in every backup folder
/// right below [root] (one per folder of the app, also of folders removed
/// since); then, while all left take more than [spaceLimit] bytes (if
/// given), those [overSpaceLimit] picks, while [goOn] holds (asked
/// before each, so a limit no longer wanted stops deleting); and the
/// folders they leave empty. Only old folders and those of deleted backups go: a new backup
/// may be on its way into a new one. Failing is harmless: what can't be
/// read or removed stays for the next time.
Future<void> pruneBackupsAt(
  String root, {
  required DateTime olderThan,
  int? spaceLimit,
  bool Function() goOn = _always,
}) async {
  final folders = [
    for (final folder in await _foldersIn(Directory(root))) folder.path,
  ];
  for (final folder in folders) {
    await fileBackupsAt(folder).prune(olderThan: olderThan);
  }
  final overLimit = spaceLimit == null
      ? const <SizedBackup<String>>[]
      : overSpaceLimit(await _sizedBackupsIn(folders), spaceLimit);
  final deleted = await _deleteInOrder(overLimit, goOn);
  for (final folder in folders) {
    final deletedHere = {
      for (final (folder: at, :backup, size: _) in deleted)
        if (at == folder) backup.folderName,
    };
    await _removeEmpty(
      await _foldersIn(Directory(folder)),
      isStale: (name) =>
          deletedHere.contains(name) ||
          (Backup.savedAtOfFolder(name)?.isBefore(olderThan) ?? false),
    );
  }
}

/// The backups in [folders], each with its size; those that can't be
/// read left out.
Future<List<SizedBackup<String>>> _sizedBackupsIn(List<String> folders) async =>
    [
      for (final folder in folders)
        if (await fileBackupsAt(folder).list() case Ok(value: final backups))
          for (final backup in backups)
            if (await _sizeOf(File('$folder/${backup.storePath.value}'))
                case final size?)
              (folder: folder, backup: backup, size: size),
    ];

Future<int?> _sizeOf(File file) async {
  try {
    return await file.length();
  } on FileSystemException {
    return null;
  }
}

/// Deletes [backups] in order, up to the first that fails or until
/// [goOn] no longer holds; those deleted.
Future<List<SizedBackup<String>>> _deleteInOrder(
  List<SizedBackup<String>> backups,
  bool Function() goOn,
) async {
  final deleted = <SizedBackup<String>>[];
  for (final sized in backups) {
    if (!goOn()) break;
    if (await fileBackupsAt(sized.folder).delete(sized.backup) is Err) break;
    deleted.add(sized);
  }
  return deleted;
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

bool _always() => true;
