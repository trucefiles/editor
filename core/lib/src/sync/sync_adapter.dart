import '../storage/rel_path.dart';

/// A sync tool's file-name rules, for the core parts its plugin builds on
/// (e.g. `DefaultFileFilter`, `LocalFileStore`'s temp files). Pure: no
/// file access. Private to the plugin: never part of `SyncTool`.
///
/// How the tool's conflicts are found is its `ConflictSource`'s job.
abstract interface class SyncAdapter {
  /// Whether [path] belongs to the sync tool itself (folder markers, version
  /// folders, temp files, conflict copies). Such files are never shown, and
  /// touched only by the tool's own `ConflictSource`.
  bool isInternal(RelPath path);

  /// Whether the folder whose path has the segments [names], outermost
  /// first, is the sync tool's own (e.g. its version folder) or lies
  /// inside it. Such a folder never holds the user's documents.
  bool isInternalFolder(List<String> names);

  /// File name for the temp file of an atomic write, placed next to the
  /// target. The sync tool must never sync it and must clean it up if left
  /// behind. [randomToken] keeps concurrent writes apart.
  String tempFileName(String randomToken);
}
