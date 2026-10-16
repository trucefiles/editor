import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';

import '../../backups/file_backups_at.dart';
import '../../platform/platform_facts.dart';
import '../../refresh/refresh_settings.dart';
import '../folder_services.dart';

/// Syncthing's file-name rules.
const SyncAdapter syncthingAdapter = SyncthingAdapter();

/// The files the app shows: notes of the types it handles, without
/// Syncthing's own files.
const FileFilter _shown = DefaultFileFilter(
  syncthingAdapter,
  ExtensionFileTypeDetector.standard(),
);

/// The files whose changes count: the shown ones, their conflict copies
/// and the marks of all devices. Nothing else, e.g. `.git` or swap files,
/// leads to a rescan.
const FileFilter _followed = AnyFileFilter([
  SyncthingFileFilter(_shown),
  NoteMarks.files,
]);

/// The core services for one folder, wired for Syncthing. [backupsPath] is
/// the folder's private backup folder in app storage; [deviceId] names this
/// device's files in the folder.
FolderServices syncthingFolderServices(
  String path, {
  required String backupsPath,
  required String deviceId,
  required PlatformFacts platform,
}) {
  const adapter = syncthingAdapter;
  final store = SyncthingMtimeWindowStore(
    LocalFileStore(
      path,
      adapter.tempFileName,
      replacesInPlace: platform.replacesInPlace,
    ),
  );
  final backups = fileBackupsAt(backupsPath);
  return FolderServices(
    store: store,
    scanner: SyncthingFolderScanner(store, _shown),
    syncToolName: adapter.name,
    conflicts: DefaultConflictService(
      folder: store,
      source: SyncthingConflictSource(store),
      backups: backups,
    ),
    backups: backups,
    restore: BackupRestore(folder: store, backups: backups),
    marks: NoteMarks(store, deviceId: deviceId),
  );
}

/// How changes to the Syncthing folder at [path] are found, as [refresh]
/// asks, and what to tell the user about the folder; built together, so
/// the notices see how changes are actually followed.
///
/// Changes are `null` for manual refresh. Otherwise watched, and polled
/// once watching fails; or only polled, at the set interval.
FolderFollowing syncthingFolderFollowing(
  String path,
  RefreshSettings refresh,
  PlatformFacts platform,
) {
  const adapter = syncthingAdapter;
  final polled = PolledFolderChanges(
    LocalFileStore(path, adapter.tempFileName),
    interval: refresh.interval,
    followed: _followed,
  );
  final syncCheck = SyncthingSyncCheck(
    path,
    readNames: readLocalFolderNames,
    parentsVisible: platform.canReadParentsOf(path),
  );
  switch (_following(path, refresh, platform)) {
    case _Following.none:
      return (changes: null, notices: SyncthingFolderNotices(syncCheck));
    case _Following.watched:
      final watched = FallbackFolderChanges(
        WatchedFolderChanges(path, followed: _followed),
        polled,
      );
      return (
        changes: watched,
        notices: SyncthingFolderNotices(
          syncCheck,
          pollInterval: () => watched.isOnFallback ? refresh.interval : null,
        ),
      );
    case _Following.polled:
      final asked = refresh.mode == RefreshMode.live;
      return (
        changes: polled,
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
_Following _following(
  String path,
  RefreshSettings refresh,
  PlatformFacts platform,
) => switch (refresh.mode) {
  RefreshMode.manual => _Following.none,
  RefreshMode.live when platform.reportsChangesIn(path) => _Following.watched,
  RefreshMode.live || RefreshMode.periodic => _Following.polled,
};
