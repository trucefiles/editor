import 'package:truce_core/truce_core.dart';

import 'syncthing_adapter.dart';
import 'syncthing_conflict_grouping.dart';

/// Changes in a Syncthing folder, without Syncthing's own files: temp files
/// of any write (Syncthing's and the app's), marker and version folders.
/// Conflict copies stay in: a new one is news.
final class SyncthingFolderChanges implements FolderChanges {
  const SyncthingFolderChanges(this._all);

  final FolderChanges _all;

  static const _adapter = SyncthingAdapter();

  @override
  Stream<RelPath> get changes => _all.changes.where(_isNews);

  static bool _isNews(RelPath path) {
    if (!_adapter.isInternal(path)) return true;
    final main = syncthingConflictMain(path);
    return main != null && !_adapter.isInternal(main);
  }
}
