import 'dart:async';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'folder_changes.dart';

/// [FolderChanges] found by listing the folder every [interval] and
/// comparing the listing with the one before. Works on any [FileStore].
///
/// A folder that is gone counts as empty, so its files show as deleted
/// and again as created once it is back. Other listing failures skip the
/// round. Never ends on its own.
final class PolledFolderChanges implements FolderChanges {
  const PolledFolderChanges(
    this._store, {
    required this.interval,
    this.enterFolder,
  });

  final FileStore _store;

  final Duration interval;

  /// Folders to look into, as for [FileStore.list]; all if `null`.
  final bool Function(RelPath folder)? enterFolder;

  @override
  Stream<RelPath> get changes {
    Timer? timer;
    late final StreamController<RelPath> controller;
    Map<RelPath, FileVersion>? last;
    var busy = false;

    Future<void> poll() async {
      if (busy) return;
      busy = true;
      try {
        final now = await _snapshot();
        final before = last;
        if (now == null || controller.isClosed) return;
        last = now;
        if (before != null) _changedPaths(before, now).forEach(controller.add);
      } finally {
        busy = false;
      }
    }

    controller = StreamController<RelPath>(
      onListen: () {
        unawaited(poll());
        timer = Timer.periodic(interval, (_) => unawaited(poll()));
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }

  /// Every file's version; empty if the folder is gone, `null` if it could
  /// not be listed.
  Future<Map<RelPath, FileVersion>?> _snapshot() async =>
      switch (await _store.list(enterFolder: enterFolder)) {
        Ok(:final value) => {
          for (final file in value.files) file.path: file.version,
        },
        Err(error: StoreError.notFound) => const {},
        Err() => null,
      };

  static Iterable<RelPath> _changedPaths(
    Map<RelPath, FileVersion> before,
    Map<RelPath, FileVersion> now,
  ) => {
    for (final MapEntry(key: path, value: version) in now.entries)
      if (before[path] != version) path,
    for (final path in before.keys)
      if (!now.containsKey(path)) path,
  };
}
