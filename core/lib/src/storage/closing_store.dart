import 'dart:async';
import 'dart:typed_data';

import '../common/result.dart';
import 'file_store.dart';
import 'rel_path.dart';

/// [FileStore] that can be closed, e.g. as the user removes its folder:
/// from [close] on, every operation answers [StoreError.closed], and
/// [close] ends once the operations under way are done. So nothing
/// reaches the folder's files after it.
final class ClosingStore implements FileStore {
  ClosingStore(this._inner);

  final FileStore _inner;
  var _running = 0;
  var _closed = false;
  Completer<void>? _idle;

  /// Refuses every new operation; done once those under way are.
  Future<void> close() async {
    _closed = true;
    if (_running > 0) await (_idle ??= Completer<void>()).future;
  }

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => _run(
    () => _inner.list(enterFolder: enterFolder, includeFile: includeFile),
  );

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) =>
      _run(() => _inner.read(path));

  @override
  Future<Result<FileEntry, StoreError>> create(RelPath path, Uint8List bytes) =>
      _run(() => _inner.create(path, bytes));

  @override
  Future<Result<void, StoreError>> createFolder(RelPath folder) =>
      _run(() => _inner.createFolder(folder));

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) => _run(() => _inner.replace(path, bytes, ifUnchanged: ifUnchanged));

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _run(() => _inner.delete(path, ifUnchanged: ifUnchanged));

  Future<Result<T, StoreError>> _run<T>(
    Future<Result<T, StoreError>> Function() operation,
  ) async {
    if (_closed) return const Err(StoreError.closed);
    _running++;
    try {
      return await operation();
    } finally {
      if (--_running == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }
}
