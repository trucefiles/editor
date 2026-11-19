import 'package:truce_core/truce_core.dart';

/// The core services for one open folder, by its plugin; the rest of the
/// app sees only this.
final class FolderServices {
  const FolderServices({
    required this.open,
    required this.apart,
    required this.conflicts,
    required this.backups,
    required this.restore,
    required this.marks,
    required this.reach,
  });

  /// The folder, opened by its plugin: its files ([OpenFolder.store],
  /// refusing other files with [StoreError.outside] and everything once
  /// closed with [StoreError.closed]), scanner, notices and changes.
  final OpenFolder open;

  FileStore get store => open.store;

  /// The files the app keeps apart in the folder (see
  /// [BoundedPlace.apart]); none where it keeps none.
  final FileStore apart;
  FolderScanner get scanner => open.scanner;

  /// What the plugin tells about the folder.
  FolderNotices get notices => open.notices;

  /// The changes of the files, the plugin's records of them and the marks
  /// of all devices, as they happen; `null` where they can't be followed
  /// live.
  FolderChanges? get changes => open.changes;

  final ConflictService conflicts;

  /// Copies of the folder's files in app storage.
  final FileBackups backups;

  /// Puts [backups] back into the folder.
  final BackupRestore restore;

  final FileMarks marks;

  /// Whether the folder can be reached, as accesses through [store] show.
  final FolderReach reach;
}

/// The services of a folder on [raw], its plugin's raw access to it, whose
/// files tell [reach] how each access went, bounded to the files the app
/// [handles] and the marks, with the files [keptApart] reached on their
/// own. Each write, the plugin's own included, is told to [wrote], but
/// those kept apart, which no screen shows. A folder that is gone is
/// checked every [checkEvery] whether it is back.
FolderServices folderServices(
  RawFolder raw, {
  required FolderReach reach,
  required bool Function(RelPath file) handles,
  required bool Function(RelPath path) keptApart,
  required String backupsPath,
  required String deviceId,
  required Duration Function() checkEvery,
  required void Function(Set<RelPath> paths) wrote,
}) {
  // Below the bound: a write it refuses is never told.
  void told(Set<RelPath> paths) {
    final shown = {...paths.where((path) => !keptApart(path))};
    if (shown.isNotEmpty) wrote(shown);
  }

  final bounded = BoundedPlace(
    WriteReportingStore(ReachReportingStore(raw.files, reach), told),
    raw.changes,
    handles: (file) => handles(file) || FileMarks.files.includesFile(file),
    keptApart: keptApart,
    checkEvery: checkEvery,
  );
  final open = raw.open(bounded);
  final backups = fileBackupsAt(backupsPath);
  return FolderServices(
    open: open,
    apart: bounded.apart,
    conflicts: DefaultConflictService(
      folder: open.store,
      source: open.conflicts,
      backups: backups,
    ),
    backups: backups,
    restore: BackupRestore(folder: open.store, backups: backups),
    marks: FileMarks(open.store, deviceId: deviceId),
    reach: reach,
  );
}
