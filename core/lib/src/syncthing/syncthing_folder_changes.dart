import 'dart:async';

import '../changes/folder_changes.dart';
import '../storage/rel_path.dart';
import 'syncthing_adapter.dart';
import 'syncthing_conflict_grouping.dart';

/// Changes in a Syncthing folder, without Syncthing's own files: temp files
/// of any write (Syncthing's and the app's), marker and version folders.
/// Conflict copies stay in: a new one is news.
///
/// Follows [_primary]; if that ends (e.g. watching failed), goes on with
/// [_fallback], if given.
final class SyncthingFolderChanges implements FolderChanges {
  const SyncthingFolderChanges(this._primary, {this._fallback});

  final FolderChanges _primary;
  final FolderChanges? _fallback;

  static const _adapter = SyncthingAdapter();

  @override
  Stream<RelPath> get changes => _followed.where(_isNews);

  Stream<RelPath> get _followed {
    final fallback = _fallback;
    if (fallback == null) return _primary.changes;
    return () async* {
      yield* _primary.changes;
      yield* fallback.changes;
    }();
  }

  static bool _isNews(RelPath path) {
    if (!_adapter.isInternal(path)) return true;
    final main = syncthingConflictMain(path);
    return main != null && !_adapter.isInternal(main);
  }
}
