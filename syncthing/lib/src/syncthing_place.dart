import 'package:truce_core/truce_core.dart';

import 'syncthing_adapter.dart';
import 'syncthing_conflict_name.dart';
import 'syncthing_folder_notices.dart';
import 'syncthing_mtime_window_store.dart';
import 'syncthing_sync_check.dart';

/// One base folder synced by Syncthing, on [_local]: its files by
/// Syncthing's rules.
final class SyncthingPlace implements ToolPlace {
  const SyncthingPlace(this._local);

  /// Syncthing's file-name rules.
  static const rules = SyncthingAdapter();
  static const _names = SyncthingConflictNames();

  final LocalPlace _local;

  @override
  FileStore get files => _local.files;

  @override
  LiveChanges? get changes => _local.changes;

  @override
  SubfolderNames get subfolders => _local.subfolders;

  /// Changes inside Syncthing's own folders (e.g. `.stversions`) are
  /// dropped: they never touch a document.
  @override
  SyncedFolder open(
    FileStore store, {
    required FolderChanges? changes,
    required FileTypeDetector types,
  }) {
    final seen = SyncthingMtimeWindowStore(store);
    final shown = DefaultFileFilter(rules, types);
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
