import '../storage/rel_path.dart';

/// A sync tool's file-name rules that other layers need. Pure: no file
/// access.
///
/// One implementation per sync tool. Syncthing is the only one for now.
/// How the tool's conflicts are found is its `ConflictSource`'s job.
abstract interface class SyncAdapter {
  /// The sync tool's name, for the UI.
  String get name;

  /// Whether [path] belongs to the sync tool itself (folder markers, version
  /// folders, temp files, conflict copies). Such files are never shown, and
  /// touched only by the tool's own `ConflictSource`.
  bool isInternal(RelPath path);

  /// Whether the folder whose path has the segments [names], outermost
  /// first, is the sync tool's own (e.g. its version folder) or lies
  /// inside it. Such a folder never holds the user's notes.
  bool isInternalFolder(List<String> names);

  /// File name for the temp file of an atomic write, placed next to the
  /// target. The sync tool must never sync it and must clean it up if left
  /// behind. [randomToken] keeps concurrent writes apart.
  String tempFileName(String randomToken);
}
