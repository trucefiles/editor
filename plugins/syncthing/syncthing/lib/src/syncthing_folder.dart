import 'package:truce_core/truce_core.dart';

import 'syncthing_conflict_name.dart';
import 'syncthing_folder_notices.dart';
import 'syncthing_mtime_window_store.dart';
import 'syncthing_rules.dart';
import 'syncthing_sync_check.dart';

/// One app folder in a Syncthing folder, on [_local], its directory: its
/// files by Syncthing's rules. [_rootMarkers] look at the Syncthing
/// folder's root, which tells whether Syncthing syncs it.
final class SyncthingFolder implements RawFolder {
  SyncthingFolder(this._local, this._rootMarkers);

  /// Syncthing's file-name rules.
  static const rules = SyncthingRules();
  static const _names = SyncthingConflictNames();

  /// What Syncthing shows of a folder: no hidden files, none of its own.
  static final shown = VisibleFileFilter(rules.isInternal);

  final LocalFolder _local;
  final FolderMarkers _rootMarkers;

  @override
  FileStore get files => _local.files;

  @override
  LiveChanges? get changes => _local.changes;

  /// Changes inside Syncthing's own folders (e.g. `.stversions`) are
  /// dropped: they never touch a file. Closing waits for a rewrite due.
  @override
  OpenFolder open(BoundedPlace bounded) {
    final writes = SyncthingWriteMemory();
    final seen = SyncthingMtimeWindowStore(bounded.files, writes);
    return OpenFolder(
      bounded,
      store: seen,
      scanner: NamedCopiesScanner(seen, shown, _names),
      showsFolder: shown.includesFolderPath,
      conflicts: NamedConflictSource(seen, _names),
      notices: SyncthingFolderNotices(SyncthingSyncCheck(_rootMarkers)),
      changes: bounded.changes?.without(
        (path) => rules.isInternalFolder(path.value.split('/')),
      ),
      settle: writes.settled,
    );
  }
}
