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
  /// Every file and folder below the root, recursively, hidden ones
  /// included. Folders for which [enterFolder] returns `false` are not
  /// walked. Filtering files is the caller's job.
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
  });

  Future<Result<FileContent, StoreError>> read(RelPath path);

  /// Creates [path] with [bytes]; fails with [StoreError.alreadyExists]
  /// instead of overwriting. Returns the new file's entry.
  ///
  /// Creates missing folders below the root. A store over a user's folder
  /// never creates the root itself: if it is gone, this fails with
  /// [StoreError.notFound], so a write never brings the folder back.
  Future<Result<FileEntry, StoreError>> create(RelPath path, Uint8List bytes);

  /// Atomically replaces [path] with [bytes]: readers see the old or the new
  /// file, never a partial one. Returns the new file's entry.
  ///
  /// Writes nothing and fails with [StoreError.changedSinceRead] if the file
  /// on disk is no longer at version [ifUnchanged].
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  });

  /// Deletes [path], with the same change check as [replace].
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  });
}

/// What [FileStore.list] found.
final class Listing {
  const Listing({required this.files, required this.folders});

  final List<FileEntry> files;

  /// The folders that were walked, empty ones included: [FileStore.list]'s
  /// `enterFolder` accepted them and they could be read.
  final List<RelPath> folders;
}

/// Names the temp file of an atomic write. [randomToken] keeps concurrent
/// writes apart.
typedef TempFileNamer = String Function(String randomToken);

/// One version of a file, for change checks.
///
/// Opaque: two versions are equal or not, nothing more. How a store tells
/// versions apart (file times, a revision number, a hash) is its own
/// business.
final class FileVersion {
  /// [token] must compare by value, e.g. a record or a number.
  const FileVersion(this._token);

  final Object _token;

  @override
  bool operator ==(Object other) =>
      other is FileVersion && other._token == _token;

  @override
  int get hashCode => _token.hashCode;
}

/// A file as the store last saw it.
final class FileEntry {
  const FileEntry(this.path, {required this.version, required this.modified});

  final RelPath path;
  final FileVersion version;

  /// When the file was last changed, for showing and sorting only; change
  /// checks use [version].
  final DateTime modified;
}

final class FileContent {
  const FileContent(
    this.bytes, {
    required this.version,
    required this.modified,
  });

  final Uint8List bytes;

  /// The version [bytes] were read from.
  final FileVersion version;

  /// See [FileEntry.modified].
  final DateTime modified;
}

enum StoreError {
  notFound,
  alreadyExists,
  changedSinceRead,
  accessDenied,
  ioFailure,
}
