import '../storage/rel_path.dart';

/// Decides which files and folders Truce looks at at all.
///
/// The single owner of that policy: the sync tool's own files, dotfiles,
/// and later unsupported file types. Scanning for conflicts and listing
/// notes both use it.
abstract interface class FileFilter {
  /// Whether the contents of [folder] are walked.
  bool includesFolder(RelPath folder);

  /// Whether [file] is seen.
  bool includesFile(RelPath file);
}
