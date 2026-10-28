import 'dart:async';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../storage/rel_path.dart';
import 'folder_changes.dart';
import 'live_changes.dart';

final _log = Logger('WatchedLiveChanges');

/// [LiveChanges] from the platform's file change events, for a folder on
/// this device.
///
/// Uses `package:watcher`, which also follows subfolders created later.
/// Only where the platform reports changes of other apps to this one and
/// the library watches natively: elsewhere it would poll every second.
/// The library reports files only, never a new empty folder.
final class WatchedLiveChanges implements LiveChanges {
  const WatchedLiveChanges(this.rootPath);

  /// Absolute path of the base folder.
  final String rootPath;

  @override
  Stream<ChangeHint> below(RelPath? folder) {
    final watcher = DirectoryWatcher(
      folder == null
          ? rootPath
          : p.joinAll([rootPath, ...folder.value.split('/')]),
    );
    return watcher.events
        .expand<ChangeHint>(
          (event) => [
            if (_relative(event.path, rootPath) case final path?)
              PathChanged(path),
          ],
        )
        .transform(_endOnError);
  }

  /// [path] relative to [root], '/'-separated on every platform.
  static RelPath? _relative(String path, String root) => p.isWithin(root, path)
      ? RelPath.parse(p.split(p.relative(path, from: root)).join('/'))
      : null;

  /// Watching failed (folder gone, too many watches): the stream ends, as
  /// [LiveChanges.below] promises.
  StreamTransformer<ChangeHint, ChangeHint> get _endOnError =>
      StreamTransformer.fromHandlers(
        handleError: (error, _, sink) {
          _log.warning('Stopped watching $rootPath: $error');
          sink.close();
        },
      );
}
