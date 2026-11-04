import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../common/result.dart';
import 'file_store.dart';
import 'rel_path.dart';

/// [FileStore] that passes every call on to [inner] as it is: the base of
/// a store that changes only some calls and overrides just those.
abstract base class ForwardingStore implements FileStore {
  const ForwardingStore(this.inner);

  /// The store the calls go on to.
  @protected
  final FileStore inner;

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => inner.list(enterFolder: enterFolder, includeFile: includeFile);

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) =>
      inner.read(path);

  @override
  Future<Result<FileEntry, StoreError>> create(RelPath path, Uint8List bytes) =>
      inner.create(path, bytes);

  @override
  Future<Result<void, StoreError>> createFolder(RelPath folder) =>
      inner.createFolder(folder);

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) => inner.replace(path, bytes, ifUnchanged: ifUnchanged);

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => inner.delete(path, ifUnchanged: ifUnchanged);
}
