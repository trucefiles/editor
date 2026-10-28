import 'package:truce_core/truce_core.dart';

import 'syncthing_adapter.dart';
import 'syncthing_conflict_name.dart';
import 'syncthing_folder_notices.dart';
import 'syncthing_mtime_window_store.dart';
import 'syncthing_sync_check.dart';

/// One base folder synced by Syncthing, on [_local]: its files by
/// Syncthing's rules.
final class SyncthingPlace implements ToolPlace {
  SyncthingPlace(this._local);

  /// Syncthing's file-name rules.
  static const rules = SyncthingAdapter();
  static const _names = SyncthingConflictNames();

  final LocalPlace _local;

  /// Kept as long as the place, so every store [open] builds goes on from
  /// the writes of the ones before.
  final _writes = SyncthingWriteMemory();

  @override
  FileStore get files => _local.files;

  @override
  LiveChanges? get changes => _local.changes;

  @override
  SubfolderNames get subfolders => _local.subfolders;

  /// Changes inside Syncthing's own folders (e.g. `.stversions`) are
  /// dropped: they never touch a document.
  @override
  SyncedFolder open(FileStore store, {required FolderChanges? changes}) {
    final seen = SyncthingMtimeWindowStore(store, _writes);
    final shown = VisibleFileFilter(rules.isInternal);
    return SyncedFolder(
      store: seen,
      scanner: NamedCopiesScanner(seen, shown, _names),
      conflicts: NamedConflictSource(seen, _names),
      notices: SyncthingFolderNotices(SyncthingSyncCheck(_local.markers)),
      changes: changes?.without(
        (path) => rules.isInternalFolder(path.value.split('/')),
      ),
      shown: shown,
    );
  }
}
