import '../common/result.dart';
import '../conflicts/conflict.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';

/// Takes stock of one folder as its sync tool sees it: the files Truce
/// shows and the conflicts waiting to be resolved.
///
/// One implementation per sync tool. How it finds the conflicts (file
/// names in the same listing, the tool's database or API) is its own
/// business.
abstract interface class FolderScanner {
  Future<Result<FolderScan, StoreError>> scan();
}

/// One scan of a folder.
final class FolderScan {
  const FolderScan({
    required this.files,
    required this.subfolders,
    required this.conflicts,
    this.unreadable = const [],
  });

  /// Files the `FileFilter` includes; never the sync tool's own files.
  final List<FileEntry> files;

  /// Every subfolder the `FileFilter` includes, empty ones too, so a note
  /// can be created there.
  final List<RelPath> subfolders;

  /// Pending conflicts of included files, grouped by main file.
  final List<Conflict> conflicts;

  /// Subfolders that could not be read: what is below them is unknown, not
  /// gone.
  final List<RelPath> unreadable;
}
