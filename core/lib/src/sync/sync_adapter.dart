import '../storage/rel_path.dart';

/// What a sync tool's own file names mean. Pure: no file access.
///
/// One implementation per sync tool. Syncthing is the only one for now.
abstract interface class SyncAdapter {
  /// Whether [path] belongs to the sync tool itself (folder markers, version
  /// folders, temp files) and must never be shown or touched.
  bool isInternal(RelPath path);

  /// Parses [path] as a conflict copy, or returns `null` if it is not one.
  ConflictCopyName? parseConflictCopy(RelPath path);

  /// File name for the temp file of an atomic write, placed next to the
  /// target. The sync tool must never sync it and must clean it up if left
  /// behind. [randomToken] keeps concurrent writes apart.
  String tempFileName(String randomToken);
}

/// What a conflict copy's file name says.
final class ConflictCopyName {
  const ConflictCopyName({required this.mainPath, this.createdAt});

  /// The file this copy conflicts with. It may no longer exist.
  final RelPath mainPath;

  /// When the sync tool created the copy, if the name says so.
  final DateTime? createdAt;
}
