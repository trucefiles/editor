import '../../common/result.dart';
import '../../filter/file_filter.dart';
import '../../scan/folder_scanner.dart';
import '../../storage/file_store.dart';
import '../../storage/rel_path.dart';
import '../../storage/selection.dart';
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

  bool _includesFileOrCopy(RelPath file) =>
      WithConflictCopies(_filter, _names).includesFile(file);

  @override
  Future<Result<FolderScan, StoreError>> scan() async {
    final listed = await _store.list(
      enterFolder: _filter.includesFolder,
      includeFile: _includesFileOrCopy,
    );
    return switch (listed) {
      Ok(
        value: Listing(files: final entries, :final folders, :final unreadable),
      ) =>
        Ok(
          FolderScan(
            files: _shownOf(entries),
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

  /// Conflict copies lie next to their main file: listing a folder's own
  /// files finds both.
  @override
  Future<Result<PartScan, StoreError>> scanIn(Set<RelPath?> asked) async {
    bool onTheWay(RelPath folder) =>
        _filter.includesFolder(folder) &&
        asked.any(
          (one) =>
              one != null && (one == folder || Selection.isInside(one, folder)),
        );
    final listed = await _store.list(
      enterFolder: onTheWay,
      includeFile: (file) =>
          asked.contains(file.parent) && _includesFileOrCopy(file),
    );
    switch (listed) {
      case Ok(
        value: Listing(files: final entries, :final folders, :final unreadable),
      ):
        bool unknown(RelPath? folder) =>
            folder != null &&
            unreadable.any(
              (blocked) =>
                  blocked == folder || Selection.isInside(folder, blocked),
            );
        return Ok(
          PartScan(
            files: _shownOf(entries),
            conflicts: groupConflictCopies(
              entries,
              _names,
              _filter.includesFile,
            ),
            found: {
              for (final folder in asked)
                if (folder == null || folders.contains(folder)) folder,
            },
            unknown: asked.where(unknown).toSet(),
          ),
        );
      case Err(:final error):
        return Err(error);
    }
  }

  List<FileEntry> _shownOf(List<FileEntry> entries) => [
    for (final entry in entries)
      if (_filter.includesFile(entry.path)) entry,
  ];
}
