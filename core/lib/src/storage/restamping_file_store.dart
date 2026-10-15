import 'dart:async';
import 'dart:typed_data';

import '../common/result.dart';
import 'file_store.dart';
import 'rel_path.dart';

/// [FileStore] that makes every write show as a change to a sync tool that
/// misses same-size rewrites in quick succession.
///
/// Some sync tools see a file as unchanged while its size stays the same
/// and its modification time moved less than a [gap]. A file written twice
/// within the gap with the same size can then keep content the tool never
/// syncs. So when a write follows the last one to the same path within the
/// gap with the same size, the same bytes are written once more after the
/// gap, unless the file changed meanwhile.
///
/// The extra write is hidden from callers: a version they got from a write
/// stays valid for their next change check. Writes to one path run one at a
/// time. Remembers each path written while it lives.
final class RestampingFileStore implements FileStore {
  RestampingFileStore(
    this._inner, {
    required this._gap,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
  }) : _now = now ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed;

  final FileStore _inner;
  final Duration _gap;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;

  final Map<RelPath, _Written> _written = {};
  final Map<RelPath, Future<void>> _queues = {};

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
      _serial(path, () async {
        final created = await _inner.create(path, bytes);
        if (created case Ok(value: final entry)) _wrote(path, bytes, entry);
        return created;
      });

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) => _serial(path, () async {
    final replaced = await _inner.replace(
      path,
      bytes,
      ifUnchanged: _onDisk(path, ifUnchanged),
    );
    if (replaced case Ok(value: final entry)) _wrote(path, bytes, entry);
    return replaced;
  });

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _serial(path, () async {
    final deleted = await _inner.delete(
      path,
      ifUnchanged: _onDisk(path, ifUnchanged),
    );
    // Keeps when and how big the last write was: a new file at the same
    // path can look like that version to the sync tool.
    if (deleted is Ok) {
      if (_written[path] case final last?) _written[path] = last.deleted();
    }
    return deleted;
  });

  /// The version on disk for a caller's [version]: the rewrite's, if the
  /// caller holds the one it replaced.
  FileVersion _onDisk(RelPath path, FileVersion version) =>
      switch (_written[path]) {
        _Written(version: final shown, :final rewrittenAs?)
            when shown == version =>
          rewrittenAs,
        _ => version,
      };

  void _wrote(RelPath path, Uint8List bytes, FileEntry entry) {
    final last = _written[path];
    final written = _Written(
      at: _now(),
      size: bytes.length,
      version: entry.version,
    );
    _written[path] = written;
    if (last != null &&
        last.size == bytes.length &&
        written.at.difference(last.at) < _gap) {
      unawaited(_rewriteLater(path, bytes, written));
    }
  }

  /// Writes [bytes] again after the gap, if [written] is still the last
  /// write to [path] and the file still holds [bytes].
  Future<void> _rewriteLater(
    RelPath path,
    Uint8List bytes,
    _Written written,
  ) async {
    await _wait(_gap);
    await _serial(path, () async {
      if (!identical(_written[path], written)) return;
      if (await _inner.read(path) case Ok(value: final content)
          when _sameBytes(content.bytes, bytes)) {
        final rewritten = await _inner.replace(
          path,
          bytes,
          ifUnchanged: content.version,
        );
        if (rewritten case Ok(value: final entry)) {
          _written[path] = written.rewritten(at: _now(), as: entry.version);
        }
      }
    });
  }

  /// Runs [operation] after every earlier write to [path] is done.
  Future<T> _serial<T>(RelPath path, Future<T> Function() operation) {
    final done = (_queues[path] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    _queues[path] = done.then<void>((_) {}, onError: (_) {});
    return done;
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The last write to a path.
final class _Written {
  const _Written({
    required this.at,
    required this.size,
    required this.version,
    this.rewrittenAs,
  });

  /// When it ended; the next same-size write within the gap is rewritten.
  final DateTime at;
  final int size;

  /// The version the caller got; `null` once the file is deleted.
  final FileVersion? version;

  /// The version on disk after the hidden rewrite, if there was one.
  final FileVersion? rewrittenAs;

  _Written rewritten({required DateTime at, required FileVersion as}) =>
      _Written(at: at, size: size, version: version, rewrittenAs: as);

  _Written deleted() => _Written(at: at, size: size, version: null);
}
