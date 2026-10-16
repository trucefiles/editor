import 'dart:async';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../filter/file_filter.dart';
import '../storage/rel_path.dart';
import 'folder_changes.dart';

final _log = Logger('WatchedFolderChanges');

/// [FolderChanges] from the platform's file change events, for a folder
/// the app opens by path.
///
/// Uses `package:watcher`, which also follows subfolders created later.
/// Only where the platform reports changes of other apps to this one and
/// the library watches natively: elsewhere it would poll every second.
///
/// The library watches every subfolder and cannot be told to skip some,
/// so the events of files [followed] leaves out are dropped here.
final class WatchedFolderChanges implements FolderChanges {
  const WatchedFolderChanges(this.rootPath, {required this.followed});

  /// Absolute path of the folder.
  final String rootPath;

  /// The files and folders whose changes count.
  final FileFilter followed;

  @override
  Stream<RelPath> get changes {
    final watcher = DirectoryWatcher(rootPath);
    return watcher.events
        .map((event) => _relative(event.path, watcher.path))
        .where((path) => path != null && followed.includesPath(path))
        .cast<RelPath>()
        .transform(_endOnError);
  }

  /// [path] relative to [root], '/'-separated on every platform.
  static RelPath? _relative(String path, String root) => p.isWithin(root, path)
      ? RelPath.parse(p.split(p.relative(path, from: root)).join('/'))
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
