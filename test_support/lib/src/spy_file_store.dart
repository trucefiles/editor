import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

/// [FileStore] that records every path it touches on [inner], for tests
/// that check what the app never touches: each folder a listing walked,
/// each file it listed, each file read, written, moved or deleted, and
/// each folder created.
final class SpyFileStore implements FileStore {
  SpyFileStore(this.inner);

  final FileStore inner;

  /// Every path touched so far, folders and files.
  final Set<RelPath> touched = {};

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => inner.list(
    enterFolder: (folder) => _record(folder, enterFolder?.call(folder) ?? true),
    includeFile: (file) => _record(file, includeFile?.call(file) ?? true),
  );

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) {
    touched.add(path);
    return inner.read(path);
  }

  @override
  Future<Result<FileEntry, StoreError>> create(RelPath path, Uint8List bytes) {
    touched.add(path);
    return inner.create(path, bytes);
  }

  @override
  Future<Result<void, StoreError>> createFolder(RelPath folder) {
    touched.add(folder);
    return inner.createFolder(folder);
  }

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) {
    touched.add(path);
    return inner.replace(path, bytes, ifUnchanged: ifUnchanged);
  }

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) {
    touched.add(path);
    return inner.delete(path, ifUnchanged: ifUnchanged);
  }

  @override
  Future<Result<FileEntry, StoreError>> move(
    RelPath from,
    RelPath to, {
    required FileVersion ifUnchanged,
  }) {
    touched.addAll([from, to]);
    return inner.move(from, to, ifUnchanged: ifUnchanged);
  }

  /// A listing touches what it walks or lists, not what it only passes.
  bool _record(RelPath path, bool taken) {
    if (taken) touched.add(path);
    return taken;
  }
}
