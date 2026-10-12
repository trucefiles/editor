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

  /// Only copies are left: the main file was deleted on another device
  /// while this one edited it.
  bool get isOrphaned => mainStamp == null;
}

final class ConflictCopy {
  const ConflictCopy({required this.path, required this.stamp, this.createdAt});

  final RelPath path;

  /// Version of the copy at scan time.
  final FileStamp stamp;

  /// When the sync tool created the copy, if known.
  final DateTime? createdAt;
}
