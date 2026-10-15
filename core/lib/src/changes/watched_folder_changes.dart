import 'dart:async';

import 'package:logging/logging.dart';
import 'package:watcher/watcher.dart';

import '../storage/rel_path.dart';
import 'folder_changes.dart';

final _log = Logger('WatchedFolderChanges');

/// [FolderChanges] from the platform's file change events, for a folder
/// the app opens by path.
///
/// Uses `package:watcher`, which also follows subfolders created later.
/// Only where the platform reports changes of other apps to this one and
/// the library watches natively: elsewhere it would poll every second.
final class WatchedFolderChanges implements FolderChanges {
  const WatchedFolderChanges(this.rootPath);

  /// Absolute path of the folder.
  final String rootPath;

  @override
  Stream<RelPath> get changes {
    final watcher = DirectoryWatcher(rootPath);
    final prefix = '${watcher.path}/';
    return watcher.events
        .map((event) => _relative(event.path, prefix))
        .where((path) => path != null)
        .cast<RelPath>()
        .transform(_endOnError);
  }

  static RelPath? _relative(String path, String prefix) =>
      path.startsWith(prefix)
      ? RelPath.parse(path.substring(prefix.length))
      : null;

  /// Watching failed (folder gone, too many watches): the stream ends, as
  /// [FolderChanges.changes] promises.
  StreamTransformer<RelPath, RelPath> get _endOnError =>
      StreamTransformer.fromHandlers(
        handleError: (error, _, sink) {
          _log.warning('Stopped watching $rootPath: $error');
          sink.close();
        },
      );
}
