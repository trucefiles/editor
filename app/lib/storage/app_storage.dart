import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:truce_core/truce_core.dart' show FolderId, loadDeviceId;

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

  /// Holds one backup folder per folder.
  String get backupsRootPath => '$rootPath/backups';

  /// Backups of one folder's files.
  String backupsPath(FolderId folder) =>
      '$backupsRootPath/${folder.storageName}';

  /// Edits not yet in one folder's files.
  String draftsPath(FolderId folder) =>
      '$rootPath/drafts/${folder.storageName}';
}

/// Set in `main` once [AppStorage.resolve] is done.
final appStorageProvider = Provider<AppStorage>(
  (ref) => throw UnimplementedError('appStorageProvider is set in main'),
);

/// This device's id (see [loadDeviceId]). Set in `main` once it is loaded.
final deviceIdProvider = Provider<String>(
  (ref) => throw UnimplementedError('deviceIdProvider is set in main'),
);
