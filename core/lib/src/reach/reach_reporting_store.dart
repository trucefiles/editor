import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'folder_reach.dart';

/// [FileStore] that tells a [FolderReach] how each access to [_inner]
/// went ([Accessed]). Changes nothing else.
final class ReachReportingStore implements FileStore {
  const ReachReportingStore(this._inner, this._reach);

  final FileStore _inner;
  final FolderReach _reach;

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => _reported(
    _inner.list(enterFolder: enterFolder, includeFile: includeFile),
  );

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) =>
      _reported(_inner.read(path));

  @override
  Future<Result<FileEntry, StoreError>> create(RelPath path, Uint8List bytes) =>
      _reported(_inner.create(path, bytes));

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) => _reported(_inner.replace(path, bytes, ifUnchanged: ifUnchanged));

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _reported(_inner.delete(path, ifUnchanged: ifUnchanged));

  @override
  Future<Result<void, StoreError>> createFolder(RelPath folder) =>
      _reported(_inner.createFolder(folder));

  @override
  Future<Result<FileEntry, StoreError>> move(
    RelPath from,
    RelPath to, {
    required FileVersion ifUnchanged,
  }) => _reported(_inner.move(from, to, ifUnchanged: ifUnchanged));

  Future<Result<T, StoreError>> _reported<T>(
    Future<Result<T, StoreError>> access,
  ) async {
    final outcome = await access;
    _reach.send(Accessed(accessOf(outcome)));
    return outcome;
  }
}
