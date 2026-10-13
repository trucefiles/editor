import '../common/result.dart';
import '../conflicts/conflict.dart';
import '../storage/file_store.dart';

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
  const FolderScan({required this.files, required this.conflicts});

  /// Files the `FileFilter` includes; never the sync tool's own files.
  final List<FileEntry> files;

  /// Pending conflicts of included files, grouped by main file.
  final List<Conflict> conflicts;
}
