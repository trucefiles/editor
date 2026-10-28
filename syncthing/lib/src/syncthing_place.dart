import 'package:truce_core/truce_core.dart';

import 'syncthing_conflict_name.dart';
import 'syncthing_folder_notices.dart';
import 'syncthing_mtime_window_store.dart';
import 'syncthing_rules.dart';
import 'syncthing_sync_check.dart';

/// One base folder synced by Syncthing, on [_local]: its files by
/// Syncthing's rules.
final class SyncthingPlace implements ToolPlace {
  SyncthingPlace(this._local);

  /// Syncthing's file-name rules.
  static const rules = SyncthingRules();
  static const _names = SyncthingConflictNames();

  /// What Syncthing shows of the folder: no hidden files, none of its own.
  static final _shown = VisibleFileFilter(rules.isInternal);

  final LocalPlace _local;

  /// Kept as long as the place, so every store [open] builds goes on from
  /// the writes of the ones before.
  final _writes = SyncthingWriteMemory();

  @override
  FileStore get files => _local.files;

  @override
  LiveChanges? get changes => _local.changes;

  @override
  SubfolderNames get subfolders => _local.subfolders.shownBy(_shown);

  /// Changes inside Syncthing's own folders (e.g. `.stversions`) are
  /// dropped: they never touch a document.
  @override
  SyncedFolder open(BoundedPlace bounded) {
    final seen = SyncthingMtimeWindowStore(bounded.files, _writes);
    return SyncedFolder(
      store: seen,
      scanner: NamedCopiesScanner(seen, _shown, _names),
      conflicts: NamedConflictSource(seen, _names),
      notices: SyncthingFolderNotices(SyncthingSyncCheck(_local.markers)),
      changes: bounded.changes?.without(
        (path) => rules.isInternalFolder(path.value.split('/')),
      ),
      shown: _shown,
    );
  }
}
