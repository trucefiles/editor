import '../common/result.dart';
import '../filter/file_filter.dart';
import '../scan/folder_scanner.dart';
import '../storage/file_store.dart';
import 'syncthing_conflict_grouping.dart';

/// Scans a Syncthing folder with one listing: Syncthing keeps conflict
/// copies as files next to their main file, so the same listing holds
/// both.
final class SyncthingFolderScanner implements FolderScanner {
  const SyncthingFolderScanner(this._store, this._filter);

  final FileStore _store;
  final FileFilter _filter;

  @override
  Future<Result<FolderScan, StoreError>> scan() async {
    final listed = await _store.list(enterFolder: _filter.includesFolder);
    return switch (listed) {
      Ok(value: Listing(files: final entries, :final folders)) => Ok(
        FolderScan(
          files: [
            for (final entry in entries)
              if (_filter.includesFile(entry.path)) entry,
          ],
          subfolders: folders,
          conflicts: groupSyncthingConflicts(entries, _filter.includesFile),
        ),
      ),
      Err(:final error) => Err(error),
    };
  }
}
