import '../storage/rel_path.dart';

/// Decides which files and folders Truce looks at at all.
///
/// The single owner of that policy: the sync tool's own files, dotfiles,
/// and files of no known type. A `FolderScanner` applies it to both the
/// files and the conflicts it finds.
abstract interface class FileFilter {
  /// Whether the contents of [folder] are walked.
  bool includesFolder(RelPath folder);

  /// Whether [file] is seen.
  bool includesFile(RelPath file);
}

/// Checks a path found without walking folders, e.g. from a change event.
extension FileFilterPaths on FileFilter {
  /// Whether [file] is included and every folder it is in is walked.
  bool includesPath(RelPath file) =>
      file.folders.every(includesFolder) && includesFile(file);

  /// Whether [folder] and every folder it is in are walked.
  bool includesFolderPath(RelPath folder) =>
      includesFolder(folder) && folder.folders.every(includesFolder);
}
