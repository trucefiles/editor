import 'dart:typed_data';

import '../common/result.dart';
import 'file_store.dart';
import 'forwarding_store.dart';
import 'rel_path.dart';

/// [FileStore] that tells [_wrote] the paths each write to [inner]
/// changed, once it worked: created, replaced or deleted. A new folder
/// changes no file, so it is not told. Changes nothing else.
final class WriteReportingStore extends ForwardingStore {
  const WriteReportingStore(super.inner, this._wrote);

  final void Function(Set<RelPath> paths) _wrote;

  @override
  Future<Result<FileEntry, StoreError>> create(RelPath path, Uint8List bytes) =>
      _reported({path}, inner.create(path, bytes));

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) => _reported({path}, inner.replace(path, bytes, ifUnchanged: ifUnchanged));

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _reported({path}, inner.delete(path, ifUnchanged: ifUnchanged));

  Future<Result<T, StoreError>> _reported<T>(
    Set<RelPath> paths,
    Future<Result<T, StoreError>> write,
  ) async {
    final result = await write;
    if (result is Ok) _wrote(paths);
    return result;
  }
}
