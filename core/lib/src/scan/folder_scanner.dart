import '../common/result.dart';
import '../conflicts/conflict.dart';
import '../filter/file_filter.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';

/// Takes stock of one folder as its sync tool sees it: the files Truce
/// shows and the conflicts waiting to be resolved.
///
/// One implementation per sync tool. How it finds the conflicts (file
/// names in the same listing, the tool's database or API) is its own
/// business.
abstract interface class FolderScanner {
  /// The whole folder; with [also], also the files that filter includes
  /// (e.g. the app's own files kept in the folder), in
  /// [FolderScan.alsoListed], from the same walk.
  Future<Result<FolderScan, StoreError>> scan({FileFilter? also});

  /// Only what lies directly in [folders] (`null`: the folder's top
  /// level), e.g. where files changed: their files and the conflicts of
  /// those files, not what is in their subfolders.
  Future<Result<PartScan, StoreError>> scanIn(Set<RelPath?> folders);
}

/// One scan of a folder.
final class FolderScan {
  const FolderScan({
    required this.files,
    required this.subfolders,
    required this.conflicts,
    this.unreadable = const [],
    this.alsoListed = const [],
  });

  /// Files the `FileFilter` includes; never the sync tool's own files.
  final List<FileEntry> files;

  /// Every subfolder the `FileFilter` includes, empty ones too, so a document
  /// can be created there.
  final List<RelPath> subfolders;

  /// Pending conflicts of included files, grouped by main file.
  final List<Conflict> conflicts;

  /// Subfolders that could not be read: what is below them is unknown, not
  /// gone.
  final List<RelPath> unreadable;

  /// The files the scan was asked to list [also].
  final List<FileEntry> alsoListed;
}

/// What [FolderScanner.scanIn] found in some folders.
final class PartScan {
  const PartScan({
    required this.files,
    required this.conflicts,
    required this.found,
    required this.unknown,
  });

  /// Of no folder.
  static const nothing = PartScan(
    files: [],
    conflicts: [],
    found: {},
    unknown: {},
  );

  /// The files the `FileFilter` includes directly in the folders [found].
  final List<FileEntry> files;

  /// The pending conflicts of files directly in the folders [found],
  /// grouped by main file.
  final List<Conflict> conflicts;

  /// The folders asked that are there and could be read.
  final Set<RelPath?> found;

  /// The folders asked that could not be read, or lie below one that
  /// could not: what is in them is unknown. Folders asked that are
  /// neither [found] nor unknown are gone.
  final Set<RelPath?> unknown;
}
