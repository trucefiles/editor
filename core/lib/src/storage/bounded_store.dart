import 'dart:typed_data';

import '../common/result.dart';
import 'file_store.dart';
import 'forwarding_store.dart';
import 'rel_path.dart';

/// [FileStore] that lets through only what the app may touch in one
/// folder: the files it [handles] (the handled file types and the app's
/// own files, e.g. marks) are listed, read and written; every other file
/// is only read, never listed or written (e.g. an image a file links).
/// Writing any other file fails with [StoreError.outside].
final class BoundedStore extends ForwardingStore {
  const BoundedStore(super.inner, {required this.handles});

  /// Whether a file is listed and written.
  final bool Function(RelPath file) handles;

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => inner.list(
    enterFolder: enterFolder,
    includeFile: (file) => handles(file) && (includeFile?.call(file) ?? true),
  );

  @override
  Future<Result<FileEntry, StoreError>> create(RelPath path, Uint8List bytes) =>
      handles(path) ? inner.create(path, bytes) : _outside();

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) => handles(path)
      ? inner.replace(path, bytes, ifUnchanged: ifUnchanged)
      : _outside();

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) =>
      handles(path) ? inner.delete(path, ifUnchanged: ifUnchanged) : _outside();

  static Future<Result<T, StoreError>> _outside<T>() async =>
      const Err(StoreError.outside);
}
