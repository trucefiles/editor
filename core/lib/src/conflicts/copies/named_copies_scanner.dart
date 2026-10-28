import '../../common/result.dart';
import '../../filter/file_filter.dart';
import '../../scan/folder_scanner.dart';
import '../../storage/file_store.dart';
import '../../storage/rel_path.dart';
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
  Future<Result<FolderScan, StoreError>> scan({FileFilter? also}) async {
    final listed = await _store.list(
      enterFolder: (folder) =>
          _filter.includesFolder(folder) ||
          (also?.includesFolder(folder) ?? false),
      includeFile: (file) =>
          _includesFileOrCopy(file) || (also?.includesFile(file) ?? false),
    );
    return switch (listed) {
      Ok(
        value: Listing(files: final entries, :final folders, :final unreadable),
      ) =>
        Ok(_scanOf(entries, folders, unreadable, also)),
      Err(:final error) => Err(error),
    };
  }

  /// What one walk listed, told apart: what the filter shows, and what
  /// was asked [also].
  FolderScan _scanOf(
    List<FileEntry> entries,
    List<RelPath> folders,
    List<RelPath> unreadable,
    FileFilter? also,
  ) {
    final own = [
      for (final entry in entries)
        if (_walked(entry.path.parent) && _includesFileOrCopy(entry.path))
          entry,
    ];
    return FolderScan(
      files: _shownOf(own),
      subfolders: folders.where(_walked).toList(),
      conflicts: groupConflictCopies(own, _names, _filter.includesFile),
      unreadable: unreadable.where(_walked).toList(),
      alsoListed: [
        if (also != null)
          for (final entry in entries)
            if (also.includesFile(entry.path)) entry,
      ],
    );
  }

  /// Conflict copies lie next to their main file: listing a folder's own
  /// files finds both.
  @override
  Future<Result<PartScan, StoreError>> scanIn(Set<RelPath?> asked) async {
    bool onTheWay(RelPath folder) =>
        _filter.includesFolder(folder) &&
        asked.any((one) => one != null && one.isAtOrInside(folder));
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
            unreadable.any((blocked) => folder.isAtOrInside(blocked));
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

  /// Whether the filter's own walk enters [folder]: it and every folder
  /// on the way to it (`null`: the top level).
  bool _walked(RelPath? folder) =>
      folder == null ||
      (_filter.includesFolder(folder) && _walked(folder.parent));

  List<FileEntry> _shownOf(List<FileEntry> entries) => [
    for (final entry in entries)
      if (_filter.includesFile(entry.path)) entry,
  ];
}
