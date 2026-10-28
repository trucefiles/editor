import 'package:truce_core/truce_core.dart';

import 'syncthing_adapter.dart';
import 'syncthing_conflict_name.dart';
import 'syncthing_folder_notices.dart';
import 'syncthing_mtime_window_store.dart';
import 'syncthing_sync_check.dart';

/// Syncthing as a sync tool plugin: recognizes its folders by their
/// marker, keeps conflict copies as files next to their main file, and
/// rewrites a save it might miss (see [SyncthingMtimeWindowStore]).
final class SyncthingTool implements SyncTool {
  const SyncthingTool();

  static const _names = SyncthingConflictNames();

  @override
  String get id => 'syncthing';

  @override
  SyncAdapter get rules => const SyncthingAdapter();

  @override
  Future<SyncStatus> recognize(FolderMarkers markers) =>
      SyncthingSyncCheck(markers).check();

  /// Syncthing keeps old versions in `.stversions` at the root of the
  /// synced folder: out of reach from any folder below it.
  @override
  Future<bool> missesOldVersions(FolderMarkers markers) async =>
      await recognize(markers) == SyncStatus.synced &&
      await markers.holds(SyncthingSyncCheck.rootMarker) != true;

  @override
  SyncedFolder open(
    FileStore store, {
    required FileFilter shown,
    required FolderMarkers markers,
    required Duration? Function() pollInterval,
  }) {
    final seen = SyncthingMtimeWindowStore(store);
    return SyncedFolder(
      store: seen,
      scanner: NamedCopiesScanner(seen, shown, _names),
      conflicts: NamedConflictSource(seen, _names),
      notices: SyncthingFolderNotices(
        SyncthingSyncCheck(markers),
        pollInterval: pollInterval,
      ),
      followed: WithConflictCopies(shown, _names),
    );
  }
}
