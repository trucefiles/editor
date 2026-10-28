import 'package:truce_core/truce_core.dart';

/// Checks a base folder for Syncthing's `.stfolder` marker, which Syncthing
/// creates in the root of every folder it syncs: the folder is synced if
/// it or one of its parents has one.
final class SyncthingSyncCheck implements SyncCheck {
  const SyncthingSyncCheck(this._markers);

  static const rootMarker = '.stfolder';

  final FolderMarkers _markers;

  /// Walks up to the file system root, and stops at the first parent it
  /// cannot read: Syncthing folders lie where apps can read. Where parents
  /// can't be seen, looks only at the folder itself.
  @override
  Future<SyncStatus> check() async {
    for (var level = 0; ; level++) {
      if (level > 0 && !_markers.seesParents) return SyncStatus.unknown;
      switch (await _markers.holds(rootMarker, levelsUp: level)) {
        case true:
          return SyncStatus.synced;
        case false:
          continue;
        case null:
          return level == 0 ? SyncStatus.unknown : SyncStatus.notSynced;
      }
    }
  }
}
