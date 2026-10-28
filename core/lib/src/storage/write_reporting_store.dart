import 'dart:typed_data';

import '../common/result.dart';
import 'file_store.dart';
import 'rel_path.dart';

/// [FileStore] that tells [_wrote] the paths each write to [_inner]
/// changed, once it worked: created, replaced, deleted, or moved (both
/// paths). Changes nothing else.
final class WriteReportingStore implements FileStore {
  const WriteReportingStore(this._inner, this._wrote);

  final FileStore _inner;
  final void Function(Set<RelPath> paths) _wrote;

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => _inner.list(enterFolder: enterFolder, includeFile: includeFile);

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) =>
      _inner.read(path);

  @override
  Future<Result<FileEntry, StoreError>> create(RelPath path, Uint8List bytes) =>
      _reported({path}, _inner.create(path, bytes));

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) =>
      _reported({path}, _inner.replace(path, bytes, ifUnchanged: ifUnchanged));

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _reported({path}, _inner.delete(path, ifUnchanged: ifUnchanged));

  @override
  Future<Result<FileEntry, StoreError>> move(
    RelPath from,
    RelPath to, {
    required FileVersion ifUnchanged,
  }) => _reported({from, to}, _inner.move(from, to, ifUnchanged: ifUnchanged));

  Future<Result<T, StoreError>> _reported<T>(
    Set<RelPath> paths,
    Future<Result<T, StoreError>> write,
  ) async {
    final result = await write;
    if (result is Ok) _wrote(paths);
    return result;
  }
}
