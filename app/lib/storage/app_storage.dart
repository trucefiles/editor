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

  /// Holds one backup folder per base folder.
  String get _backupsRootPath => '$rootPath/backups';

  /// Backups of one base folder's files, by [baseId].
  String backupsPath(String baseId) => '$_backupsRootPath/$baseId';

  /// Edits not yet in one base folder's document files, by [baseId].
  String draftsPath(String baseId) => '$rootPath/drafts/$baseId';

  /// Every backup folder, also of base folders removed from the app since.
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

  /// Removes the empty folders in the folders right below [path] whose
  /// name [isStale] accepts, those folders included; e.g. the ones pruned
  /// backups leave. Other folders are never touched, so a folder being
  /// filled right now stays. Folders that can't be removed stay.
  Future<void> removeEmptyFolders(
    String path, {
    required bool Function(String name) isStale,
  }) async {
    final folders = <Directory>[];
    try {
      await for (final entity in Directory(path).list(followLinks: false)) {
        if (entity is! Directory) continue;
        if (!isStale(entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty))) {
          continue;
        }
        folders
          ..add(entity)
          ..addAll(
            await entity
                .list(recursive: true, followLinks: false)
                .where((inner) => inner is Directory)
                .cast<Directory>()
                .toList(),
          );
      }
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
