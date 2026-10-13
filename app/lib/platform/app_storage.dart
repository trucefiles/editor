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

  /// Holds one backup folder per note folder.
  String get _backupsRootPath => '$rootPath/backups';

  /// Conflict backups of one folder, by [folderId].
  String backupsPath(String folderId) => '$_backupsRootPath/$folderId';

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
}

/// Set in `main` once [AppStorage.resolve] is done.
final appStorageProvider = Provider<AppStorage>(
  (ref) => throw UnimplementedError('appStorageProvider is set in main'),
);
