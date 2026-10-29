import 'package:truce_core/truce_core.dart';

import '../backups/file_backups_at.dart';

/// The core services for one base folder, by its sync tool, bounded to
/// what its folders show; the rest of the app sees only this.
final class BaseFolderServices {
  const BaseFolderServices({
    required this.store,
    required this.scanner,
    required this.syncToolName,
    required this.conflicts,
    required this.backups,
    required this.restore,
    required this.marks,
    required this.reach,
    required this.notices,
    required this.changes,
  });

  /// The base folder's files, by its sync tool; refuses anything outside
  /// what its folders show ([StoreError.outside]); tells [reach] how each
  /// access went.
  final FileStore store;
  final FolderScanner scanner;

  /// The sync tool's name, for the UI.
  final String syncToolName;

  final ConflictService conflicts;

  /// Copies of the base folder's files in app storage.
  final FileBackups backups;

  /// Puts [backups] back into the base folder.
  final BackupRestore restore;

  final DocumentMarks marks;

  /// Whether the base folder can be reached, as accesses through [store]
  /// show.
  final FolderReach reach;

  /// What the sync tool tells about the base folder.
  final FolderNotices notices;

  /// The changes of the documents, the sync tool's records of them and the
  /// marks of all devices, as they happen; `null` where they can't be
  /// followed live.
  final FolderChanges? changes;
}

/// The services of a base folder on [place], its sync tool's access to it,
/// whose files tell [reach] how each access went, bounded to [selection]:
/// the files the app [handles] and the marks. Each write, the sync
/// tool's own included, is told to [wrote]. A followed subfolder that is
/// gone is checked every [checkEvery] whether it is back.
BaseFolderServices baseFolderServices(
  ToolPlace place, {
  required String syncToolName,
  required FolderReach reach,
  required Selection selection,
  required bool Function(RelPath file) handles,
  required String backupsPath,
  required String deviceId,
  required Duration Function() checkEvery,
  required void Function(Set<RelPath> paths) wrote,
}) {
  // Below the boundary: a write it refuses is never told.
  final bounded = BoundedPlace(
    WriteReportingStore(ReachReportingStore(place.files, reach), wrote),
    place.changes,
    selection,
    handles: (file) => handles(file) || DocumentMarks.files.includesFile(file),
    checkEvery: checkEvery,
  );
  final synced = place.open(bounded);
  final backups = fileBackupsAt(backupsPath);
  return BaseFolderServices(
    store: synced.store,
    scanner: synced.scanner,
    syncToolName: syncToolName,
    conflicts: DefaultConflictService(
      folder: synced.store,
      source: synced.conflicts,
      backups: backups,
    ),
    backups: backups,
    restore: BackupRestore(folder: synced.store, backups: backups),
    marks: DocumentMarks(synced.store, deviceId: deviceId),
    reach: reach,
    notices: synced.notices,
    changes: synced.changes,
  );
}
