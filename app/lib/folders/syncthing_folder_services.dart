import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../platform/change_events.dart';
import '../platform/parent_folder_access.dart';
import '../refresh/refresh_settings.dart';
import 'folder_services.dart';

/// Syncthing's file-name rules.
const SyncAdapter syncthingAdapter = SyncthingAdapter();

/// The core services for one folder, wired for Syncthing. [backupsPath] is
/// the folder's private backup folder in app storage; [deviceId] names this
/// device's files in the folder.
FolderServices syncthingFolderServices(
  String path, {
  required String backupsPath,
  required String deviceId,
}) {
  const adapter = syncthingAdapter;
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
/// asks, and what to tell the user about the folder; built together, so
/// the notices see how changes are actually followed.
///
/// Changes are `null` for manual refresh. Otherwise watched, and polled
/// once watching fails; or only polled, at the set interval.
FolderFollowing syncthingFolderFollowing(String path, RefreshSettings refresh) {
  const adapter = syncthingAdapter;
  final polled = PolledFolderChanges(
    LocalFileStore(path, adapter.tempFileName),
    interval: refresh.interval,
    enterFolder: (folder) => !adapter.isInternal(folder),
  );
  final syncCheck = SyncthingSyncCheck(
    path,
    readNames: readLocalFolderNames,
    parentsVisible: canReadParents(path),
  );
  switch (_following(path, refresh)) {
    case _Following.none:
      return (changes: null, notices: SyncthingFolderNotices(syncCheck));
    case _Following.watched:
      final watched = FallbackFolderChanges(WatchedFolderChanges(path), polled);
      return (
        changes: SyncthingFolderChanges(watched),
        notices: SyncthingFolderNotices(
          syncCheck,
          pollInterval: () => watched.isOnFallback ? refresh.interval : null,
        ),
      );
    case _Following.polled:
      final asked = refresh.mode == RefreshMode.live;
      return (
        changes: SyncthingFolderChanges(polled),
        notices: SyncthingFolderNotices(
          syncCheck,
          pollInterval: () => asked ? refresh.interval : null,
        ),
      );
  }
}

/// How a Syncthing folder's changes are followed.
enum _Following { none, watched, polled }

/// The one place that decides how the folder at [path] follows changes for
/// [refresh]: live means watched where the platform reports the folder's
/// changes, polled elsewhere.
_Following _following(String path, RefreshSettings refresh) =>
    switch (refresh.mode) {
      RefreshMode.manual => _Following.none,
      RefreshMode.live when reportsChanges(path) => _Following.watched,
      RefreshMode.live || RefreshMode.periodic => _Following.polled,
    };

/// The conflict backups in the app storage folder at [path], which is
/// created with the first backup.
ConflictBackups conflictBackupsAt(String path) => ConflictBackups(
  LocalFileStore(
    path,
    const SyncthingAdapter().tempFileName,
    createsRoot: true,
  ),
);
