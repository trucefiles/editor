import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../platform/change_events.dart';
import '../platform/parent_folder_access.dart';
import '../refresh/refresh_settings.dart';
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
    conflicts: DefaultConflictService(
      folder: store,
      source: SyncthingConflictSource(store),
      backups: conflictBackupsAt(backupsPath),
    ),
    marks: NoteMarks(store, deviceId: deviceId),
  );
}

/// How changes to the Syncthing folder at [path] are found, as [refresh]
/// asks; `null` for manual refresh. Live where the platform reports this
/// folder's changes, polled at the set interval otherwise, and also once
/// watching fails.
FolderChanges? syncthingFolderChanges(String path, RefreshSettings refresh) {
  const adapter = SyncthingAdapter();
  final polled = PolledFolderChanges(
    LocalFileStore(path, adapter.tempFileName),
    interval: refresh.interval,
    enterFolder: (folder) => !adapter.isInternal(folder),
  );
  return switch (refresh.mode) {
    RefreshMode.manual => null,
    RefreshMode.live when reportsChanges(path) => SyncthingFolderChanges(
      WatchedFolderChanges(path),
      fallback: polled,
    ),
    RefreshMode.live || RefreshMode.periodic => SyncthingFolderChanges(polled),
  };
}

/// What the user should know about the Syncthing folder at [path]: whether
/// Syncthing syncs it, and when [refresh] asks for live updates that this
/// folder can't give.
FolderNotices syncthingFolderNotices(String path, RefreshSettings refresh) =>
    SyncthingFolderNotices(
      SyncthingSyncCheck(
        path,
        readNames: readLocalFolderNames,
        parentsVisible: canReadParents(path),
      ),
      pollInterval: refresh.mode == RefreshMode.live && !reportsChanges(path)
          ? refresh.interval
          : null,
    );

/// The conflict backups in the app storage folder at [path], which is
/// created with the first backup.
ConflictBackups conflictBackupsAt(String path) => ConflictBackups(
  LocalFileStore(
    path,
    const SyncthingAdapter().tempFileName,
    createsRoot: true,
  ),
);
