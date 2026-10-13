import '../storage/rel_path.dart';
import '../sync/sync_adapter.dart';
import 'syncthing_conflict_name.dart';

/// Syncthing's file-name rules.
///
/// Works for any folder inside a Syncthing folder, root or subfolder: it
/// matches names, never looks for the folder's root.
final class SyncthingAdapter implements SyncAdapter {
  const SyncthingAdapter();

  /// Syncthing's own files and folders, at the root of a Syncthing folder.
  static const _internalNames = {'.stfolder', '.stignore', '.stversions'};

  @override
  String get name => 'Syncthing';

  @override
  bool isInternal(RelPath path) =>
      path.value.split('/').any(_internalNames.contains) ||
      _isTempFile(path.name) ||
      SyncthingConflictName.parse(path.name) != null;

  /// Syncthing never syncs `.syncthing.*` files and deletes stale ones
  /// after a day, so a temp file left by a crash is cleaned up.
  @override
  String tempFileName(String randomToken) =>
      '.syncthing.truce-$randomToken.tmp';

  /// Syncthing's temp files: `.syncthing.*.tmp`, and `~syncthing~*.tmp`
  /// on Windows.
  static bool _isTempFile(String name) =>
      (name.startsWith('.syncthing.') || name.startsWith('~syncthing~')) &&
      name.endsWith('.tmp');
}
