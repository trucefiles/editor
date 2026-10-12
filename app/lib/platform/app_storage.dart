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

  /// Conflict backups of one folder, by [folderId].
  String backupsPath(String folderId) => '$rootPath/backups/$folderId';
}

/// Set in `main` once [AppStorage.resolve] is done.
final appStorageProvider = Provider<AppStorage>(
  (ref) => throw UnimplementedError('appStorageProvider is set in main'),
);
