import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/app_storage.dart';
import '../platform/device_id.dart';
import '../platform/parent_folder_access.dart';
import 'note_folder.dart';

/// The core services for one folder, wired for Syncthing. The only place
/// in the app that picks implementations.
final class FolderServices {
  /// [backupsPath] is the folder's private backup folder in app storage;
  /// [deviceId] names this device's files in the folder.
  factory FolderServices.syncthing(
    String path, {
    required String backupsPath,
    required String deviceId,
  }) {
    const adapter = SyncthingAdapter();
    const filter = DefaultFileFilter(
      adapter,
      ExtensionFileTypeDetector.standard(),
    );
    final store = RestampingFileStore(
      LocalFileStore(
        path,
        adapter.tempFileName,
        // On Android shared storage, a renamed-over file soon shows other
        // apps the old file's modification time, so sync tools miss the
        // save.
        replacesInPlace: Platform.isAndroid,
      ),
      gap: adapter.sameSizeRewriteGap,
    );
    return FolderServices._(
      store: store,
      scanner: SyncthingFolderScanner(store, filter),
      syncToolName: adapter.name,
      syncCheck: SyncthingSyncCheck(
        path,
        readNames: readLocalFolderNames,
        parentsVisible: canReadParents(path),
      ),
      conflicts: DefaultConflictService(
        folder: store,
        source: SyncthingConflictSource(store),
        backups: conflictBackupsAt(backupsPath),
      ),
      marks: NoteMarks(store, deviceId: deviceId),
    );
  }

  const FolderServices._({
    required this.store,
    required this.scanner,
    required this.syncToolName,
    required this.syncCheck,
    required this.conflicts,
    required this.marks,
  });

  final FileStore store;
  final FolderScanner scanner;

  /// The sync tool's name, for the UI.
  final String syncToolName;

  final SyncCheck syncCheck;
  final ConflictService conflicts;
  final NoteMarks marks;
}

/// The conflict backups in the app storage folder at [path], which is
/// created with the first backup.
ConflictBackups conflictBackupsAt(String path) => ConflictBackups(
  LocalFileStore(
    path,
    const SyncthingAdapter().tempFileName,
    createsRoot: true,
  ),
);

final folderServicesProvider = Provider.family<FolderServices, FolderLocation>(
  (ref, location) => FolderServices.syncthing(
    location.path,
    backupsPath: ref.watch(appStorageProvider).backupsPath(location.id),
    deviceId: ref.watch(deviceIdProvider),
  ),
);
