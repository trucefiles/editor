import '../storage/file_store.dart';
import '../storage/rel_path.dart';

/// A main file and the conflict copies waiting to be resolved against it.
final class Conflict {
  const Conflict({
    required this.mainPath,
    required this.mainStamp,
    required this.copies,
  });

  final RelPath mainPath;

  /// Version of the main file at scan time; `null` if it no longer exists.
  final FileStamp? mainStamp;

  /// Never empty. Ordered as they must be resolved, oldest first.
  final List<ConflictCopy> copies;

  /// Only copies are left. Syncthing does this when a file is edited on one
  /// device and later deleted on another: the delete wins, and the edit
  /// survives only as a conflict copy.
  bool get isOrphaned => mainStamp == null;
}

final class ConflictCopy {
  const ConflictCopy({required this.id, required this.stamp, this.createdAt});

  /// Identifies the copy within its `ConflictSource`; opaque to everyone
  /// else (for Syncthing, the copy's file path).
  final String id;

  /// Version of the copy at scan time.
  final FileStamp stamp;

  /// When the sync tool created the copy, if known.
  final DateTime? createdAt;
}
