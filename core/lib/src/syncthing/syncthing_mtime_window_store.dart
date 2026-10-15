import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';

/// [FileStore] that makes sure Syncthing sees every write.
///
/// Syncthing treats a file as unchanged while its size is the same and its
/// modification time is within the folder's mtime window (`modTimeWindowS`:
/// 2 s by default on Android, settable everywhere) of the version it last
/// indexed. It may index any version, at any time. So a write less than
/// [window] after an earlier version of the file can keep content Syncthing
/// never syncs. After such a write, the same bytes are written once more,
/// [window] after that earlier version, unless the file changed meanwhile.
///
/// Earlier versions are the ones this store wrote, and the ones it read
/// (by their modification time). A write that follows the last one within
/// the window moves the rewrite: one per file at a time.
///
/// A version a caller got from a write stays valid for its next change
/// check ([replace], [delete]) after the rewrite. [read] and [list] show
/// the rewrite's version: a new version of the same bytes. Writes to one
/// file run one at a time, so a rewrite never interleaves with a write.
///
/// A rewrite that fails, or that does not happen because the app ends
/// first, is not retried: the content may then stay unseen until the
/// file's next write. Each rewrite is logged.
final class SyncthingMtimeWindowStore implements FileStore {
  SyncthingMtimeWindowStore(
    this._inner, {
    DateTime Function()? now,
    Timer Function(Duration, void Function())? timer,
  }) : _now = now ?? DateTime.now,
       _timer = timer ?? Timer.new;

  /// Syncthing's default mtime window.
  static const window = Duration(seconds: 2);

  /// File times can lag the clock a little; the rewrite waits this much
  /// longer, so its time is surely outside the window.
  static const margin = Duration(milliseconds: 100);

  static final _log = Logger('truce.syncthing');

  final FileStore _inner;
  final DateTime Function() _now;
  final Timer Function(Duration, void Function()) _timer;

  final Map<RelPath, _FileState> _files = {};
  final Map<RelPath, Future<void>> _queues = {};

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => _inner.list(enterFolder: enterFolder, includeFile: includeFile);

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) async {
    final read = await _inner.read(path);
    if (read case Ok(value: final content)) {
      _stateOf(path).saw(content.modified);
    }
    return read;
  }

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
      ifUnchanged: _stateOf(path).onDisk(ifUnchanged),
    );
    if (replaced case Ok(value: final entry)) _wrote(path, bytes, entry);
    return replaced;
  });

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _serial(path, () async {
    final state = _stateOf(path);
    final deleted = await _inner.delete(
      path,
      ifUnchanged: state.onDisk(ifUnchanged),
    );
    // Keeps the newest time: a new file at the same path can look like
    // the deleted version to Syncthing.
    if (deleted is Ok) state.forget();
    return deleted;
  });

  _FileState _stateOf(RelPath path) => _files.putIfAbsent(path, _FileState.new);

  void _wrote(RelPath path, Uint8List bytes, FileEntry entry) {
    final state = _stateOf(path);
    final earlier = state.newest;
    final now = _now();
    state.wrote(entry.version, at: now);
    // An earlier time can be ahead of the clock: Syncthing keeps the mtimes
    // of other devices. Far enough ahead, it is outside the window too.
    if (earlier == null || now.difference(earlier).abs() >= window) return;
    state.due = _timer(earlier.add(window + margin).difference(now), () {
      state.due = null;
      unawaited(_rewrite(path, bytes, entry.version));
    });
  }

  /// Writes [bytes] again if [written] is still the last write to [path]
  /// and the file still holds [bytes].
  Future<void> _rewrite(RelPath path, Uint8List bytes, FileVersion written) =>
      _serial(path, () async {
        final state = _stateOf(path);
        if (state.version != written) return;
        switch (await _inner.read(path)) {
          case Ok(value: final content) when _sameBytes(content.bytes, bytes):
            switch (await _inner.replace(
              path,
              bytes,
              ifUnchanged: content.version,
            )) {
              case Ok(value: final entry):
                state.rewrote(entry.version, at: _now());
                _log.info(
                  'Rewrote ${path.value} unchanged, so Syncthing sees its '
                  'last write (less than ${window.inSeconds} s after an '
                  'earlier version)',
                );
              case Err(:final error):
                _log.warning('Could not rewrite ${path.value}: $error');
            }
          case Ok():
            // Changed meanwhile: that change is what Syncthing must see.
            break;
          case Err(:final error):
            _log.warning('Could not rewrite ${path.value}: $error');
        }
      });

  /// Runs [operation] after every earlier write to [path] is done.
  Future<T> _serial<T>(RelPath path, Future<T> Function() operation) {
    final done = (_queues[path] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    final tail = done.then<void>((_) {}, onError: (_) {});
    _queues[path] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_queues[path], tail)) _queues.remove(path);
      }),
    );
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

/// What the store knows about one file.
final class _FileState {
  /// Time of the newest version known: written or read.
  DateTime? newest;

  /// The version the last write returned to its caller; `null` once the
  /// file is deleted.
  FileVersion? version;

  /// The version on disk after a hidden rewrite of [version].
  FileVersion? rewrittenAs;

  /// The pending rewrite.
  Timer? due;

  /// The version on disk for a caller's [held] version.
  FileVersion onDisk(FileVersion held) =>
      held == version ? (rewrittenAs ?? held) : held;

  void saw(DateTime modified) {
    if (newest == null || modified.isAfter(newest!)) newest = modified;
  }

  void wrote(FileVersion written, {required DateTime at}) {
    _cancelDue();
    version = written;
    rewrittenAs = null;
    newest = at;
  }

  void rewrote(FileVersion rewritten, {required DateTime at}) {
    rewrittenAs = rewritten;
    newest = at;
  }

  void forget() {
    _cancelDue();
    version = null;
    rewrittenAs = null;
  }

  void _cancelDue() {
    due?.cancel();
    due = null;
  }
}
