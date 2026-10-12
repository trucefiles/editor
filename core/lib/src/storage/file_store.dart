import 'dart:typed_data';

import '../common/result.dart';
import 'rel_path.dart';

/// Byte-level access to all files under one root folder.
///
/// Knows nothing about sync tools or file types. Implementations are
/// platform-specific (plain file system, Android, Linux portal, in-memory
/// fake for tests); everything above sees only this interface.
///
/// Atomic writes go through a temp file next to the target. Implementations
/// get a [TempFileNamer] when built, so storage never depends on the sync
/// layer; the wiring passes in the sync tool's naming rule.
abstract interface class FileStore {
  /// Every file below the root, recursively, hidden files included.
  /// Folders for which [enterFolder] returns `false` are not walked.
  /// Filtering files is the caller's job.
  Future<Result<List<FileEntry>, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
  });

  Future<Result<FileContent, StoreError>> read(RelPath path);

  /// Creates [path] with [bytes]; fails with [StoreError.alreadyExists]
  /// instead of overwriting.
  Future<Result<FileStamp, StoreError>> create(RelPath path, Uint8List bytes);

  /// Atomically replaces [path] with [bytes]: readers see the old or the new
  /// file, never a partial one.
  ///
  /// Writes nothing and fails with [StoreError.changedSinceRead] if the file
  /// on disk no longer matches [ifUnchanged].
  Future<Result<FileStamp, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileStamp ifUnchanged,
  });

  /// Deletes [path], with the same change check as [replace].
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileStamp ifUnchanged,
  });
}

/// Names the temp file of an atomic write. [randomToken] keeps concurrent
/// writes apart.
typedef TempFileNamer = String Function(String randomToken);

/// Identifies one version of a file on disk, for change checks.
final class FileStamp {
  const FileStamp({required this.modified, required this.size});

  final DateTime modified;
  final int size;

  @override
  bool operator ==(Object other) =>
      other is FileStamp && other.modified == modified && other.size == size;

  @override
  int get hashCode => Object.hash(modified, size);
}

final class FileEntry {
  const FileEntry(this.path, this.stamp);

  final RelPath path;
  final FileStamp stamp;
}

final class FileContent {
  const FileContent(this.bytes, this.stamp);

  final Uint8List bytes;
  final FileStamp stamp;
}

enum StoreError {
  notFound,
  alreadyExists,
  changedSinceRead,
  accessDenied,
  ioFailure,
}
