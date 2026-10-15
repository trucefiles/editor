import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../platform/parent_folder_access.dart';
import 'folder_services.dart';

/// The core services for one folder, wired for Syncthing. [backupsPath] is
/// the folder's private backup folder in app storage; [deviceId] names this
/// device's files in the folder.
FolderServices syncthingFolderServices(
  String path, {
  required String backupsPath,
  required String deviceId,
}) {
  const adapter = SyncthingAdapter();
  const filter = DefaultFileFilter(
    adapter,
    ExtensionFileTypeDetector.standard(),
  );
  final store = SyncthingMtimeWindowStore(
    LocalFileStore(
      path,
      adapter.tempFileName,
      // On Android shared storage, a renamed-over file soon shows other
      // apps the old file's modification time, so sync tools miss the
      // save.
      replacesInPlace: Platform.isAndroid,
    ),
  );
  return FolderServices(
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

/// The conflict backups in the app storage folder at [path], which is
/// created with the first backup.
ConflictBackups conflictBackupsAt(String path) => ConflictBackups(
  LocalFileStore(
    path,
    const SyncthingAdapter().tempFileName,
    createsRoot: true,
  ),
);
