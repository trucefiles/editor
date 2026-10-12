import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import 'test_helpers.dart';

/// In-memory [FileStore] for tests. Each write gets a new, later stamp.
final class MemoryFileStore implements FileStore {
  final Map<RelPath, FileContent> files = {};

  /// When set, every operation fails with this error.
  StoreError? failWith;

  int _clock = 0;

  /// Adds or overwrites [path] without any checks.
  FileStamp put(String path, String text) {
    final bytes = bytesOf(text);
    final stamp = _nextStamp(bytes);
    files[RelPath.parse(path)!] = FileContent(bytes, stamp);
    return stamp;
  }

  String? textOf(String path) {
    final content = files[RelPath.parse(path)!];
    return content == null ? null : String.fromCharCodes(content.bytes);
  }

  @override
  Future<Result<List<FileEntry>, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
  }) async {
    if (failWith case final error?) return Err(error);
    bool entered(RelPath path) {
      final segments = path.value.split('/');
      for (var i = 1; i < segments.length; i++) {
        final folder = RelPath.parse(segments.take(i).join('/'))!;
        if (!(enterFolder?.call(folder) ?? true)) return false;
      }
      return true;
    }

    return Ok([
      for (final MapEntry(key: path, value: content) in files.entries)
        if (entered(path)) FileEntry(path, content.stamp),
    ]);
  }

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) async {
    if (failWith case final error?) return Err(error);
    final content = files[path];
    return content == null ? const Err(StoreError.notFound) : Ok(content);
  }

  @override
  Future<Result<FileStamp, StoreError>> create(
    RelPath path,
    Uint8List bytes,
  ) async {
    if (failWith case final error?) return Err(error);
    if (files.containsKey(path)) return const Err(StoreError.alreadyExists);
    return Ok(_write(path, bytes));
  }

  @override
  Future<Result<FileStamp, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileStamp ifUnchanged,
  }) async {
    if (_check(path, ifUnchanged) case final error?) return Err(error);
    return Ok(_write(path, bytes));
  }

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileStamp ifUnchanged,
  }) async {
    if (_check(path, ifUnchanged) case final error?) return Err(error);
    files.remove(path);
    return const Ok(null);
  }

  StoreError? _check(RelPath path, FileStamp expected) {
    if (failWith case final error?) return error;
    final content = files[path];
    if (content == null) return StoreError.notFound;
    return content.stamp == expected ? null : StoreError.changedSinceRead;
  }

  FileStamp _write(RelPath path, Uint8List bytes) {
    final stamp = _nextStamp(bytes);
    files[path] = FileContent(bytes, stamp);
    return stamp;
  }

  FileStamp _nextStamp(Uint8List bytes) => FileStamp(
    modified: DateTime.fromMillisecondsSinceEpoch(++_clock),
    size: bytes.length,
  );
}
