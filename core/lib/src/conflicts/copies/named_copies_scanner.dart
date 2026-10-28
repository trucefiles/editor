import '../../common/result.dart';
import '../../filter/file_filter.dart';
import '../../scan/folder_scanner.dart';
import '../../storage/file_store.dart';
import 'conflict_copy_grouping.dart';
import 'conflict_copy_names.dart';
import 'with_conflict_copies.dart';

/// Scans a folder whose sync tool keeps conflict copies as files next to
/// their main file, named by [_names], with one listing: it holds both.
/// Lists only included files and their conflict copies.
final class NamedCopiesScanner implements FolderScanner {
  const NamedCopiesScanner(this._store, this._filter, this._names);

  final FileStore _store;
  final FileFilter _filter;
  final ConflictCopyNames _names;

  @override
  Future<Result<FolderScan, StoreError>> scan() async {
    final listed = await _store.list(
      enterFolder: _filter.includesFolder,
      includeFile: WithConflictCopies(_filter, _names).includesFile,
    );
    return switch (listed) {
      Ok(
        value: Listing(files: final entries, :final folders, :final unreadable),
      ) =>
        Ok(
          FolderScan(
            files: [
              for (final entry in entries)
                if (_filter.includesFile(entry.path)) entry,
            ],
            subfolders: folders,
            conflicts: groupConflictCopies(
              entries,
              _names,
              _filter.includesFile,
            ),
            unreadable: unreadable,
          ),
        ),
      Err(:final error) => Err(error),
    };
  }
}
