import 'package:truce_core/truce_core.dart';

/// The core services for one open folder, by its plugin; the rest of the
/// app sees only this.
final class FolderServices {
  const FolderServices({
    required this.open,
    required this.pluginName,
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
  FolderScanner get scanner => open.scanner;

  /// What the plugin tells about the folder.
  FolderNotices get notices => open.notices;

  /// The changes of the files, the plugin's records of them and the marks
  /// of all devices, as they happen; `null` where they can't be followed
  /// live.
  FolderChanges? get changes => open.changes;

  /// The plugin's name, for the UI.
  final String pluginName;

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
/// [handles] and the marks. Each write, the plugin's own included, is
/// told to [wrote]. A folder that is gone is checked every [checkEvery]
/// whether it is back.
FolderServices folderServices(
  RawFolder raw, {
  required String pluginName,
  required FolderReach reach,
  required bool Function(RelPath file) handles,
  required String backupsPath,
  required String deviceId,
  required Duration Function() checkEvery,
  required void Function(Set<RelPath> paths) wrote,
}) {
  // Below the bound: a write it refuses is never told.
  final bounded = BoundedPlace(
    WriteReportingStore(ReachReportingStore(raw.files, reach), wrote),
    raw.changes,
    handles: (file) => handles(file) || FileMarks.files.includesFile(file),
    checkEvery: checkEvery,
  );
  final open = raw.open(bounded);
  final backups = fileBackupsAt(backupsPath);
  return FolderServices(
    open: open,
    pluginName: pluginName,
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
