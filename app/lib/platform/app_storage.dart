import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Where the app keeps its own files, private to this device.
final class AppStorage {
  const AppStorage(this.rootPath);

  /// Resolves the platform's app support folder.
  static Future<AppStorage> resolve() async =>
      AppStorage((await getApplicationSupportDirectory()).path);

  final String rootPath;

  String get settingsPath => '$rootPath/settings';

  /// This device's id; kept out of Android backups (see
  /// `android/app/src/main/res/xml`).
  String get deviceIdPath => '$settingsPath/device_id';

  /// Holds one backup folder per note folder.
  String get _backupsRootPath => '$rootPath/backups';

  /// Note backups of one folder, by [folderId].
  String backupsPath(String folderId) => '$_backupsRootPath/$folderId';

  /// Edits not yet in one folder's note files, by [folderId].
  String draftsPath(String folderId) => '$rootPath/drafts/$folderId';

  /// Every backup folder, also of folders removed from the app since.
  Future<List<String>> allBackupsPaths() async {
    try {
      return await Directory(_backupsRootPath)
          .list(followLinks: false)
          .where((entity) => entity is Directory)
          .map((folder) => folder.path)
          .toList();
    } on FileSystemException {
      return const [];
    }
  }

  /// Removes the empty folders below [path], e.g. those left by pruned
  /// backups. Folders that can't be removed stay.
  Future<void> removeEmptyFolders(String path) async {
    final List<Directory> folders;
    try {
      folders = await Directory(path)
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is Directory)
          .cast<Directory>()
          .toList();
    } on FileSystemException {
      return;
    }
    // Deepest first, so a folder holding only empty folders goes too.
    folders.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final folder in folders) {
      try {
        // Not recursive: fails for a folder that still holds anything.
        await folder.delete();
      } on FileSystemException {
        continue;
      }
    }
  }
}

/// Set in `main` once [AppStorage.resolve] is done.
final appStorageProvider = Provider<AppStorage>(
  (ref) => throw UnimplementedError('appStorageProvider is set in main'),
);
