import 'package:truce_core/truce_core.dart';

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
  bool isInternal(RelPath path) =>
      _hasInternalName(path.value.split('/')) ||
      _isTempFile(path.name) ||
      const SyncthingConflictNames().parse(path.name) != null;

  @override
  bool isInternalFolder(List<String> names) => _hasInternalName(names);

  static bool _hasInternalName(List<String> names) =>
      names.any(_internalNames.contains);

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
