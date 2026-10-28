import 'package:truce_core/truce_core.dart';

import 'syncthing_conflict_name.dart';

/// Syncthing's file-name rules.
///
/// Works for any folder inside a Syncthing folder, root or subfolder: it
/// matches names, never looks for the folder's root.
final class SyncthingRules {
  const SyncthingRules();

  /// Syncthing's own files and folders, at the root of a Syncthing folder.
  static const _internalNames = {'.stfolder', '.stignore', '.stversions'};

  /// Whether [path] belongs to the sync tool itself (folder markers,
  /// version folders, temp files, conflict copies): never shown.
  bool isInternal(RelPath path) =>
      _hasInternalName(path.value.split('/')) ||
      _isTempFile(path.name) ||
      const SyncthingConflictNames().parse(path.name) != null;

  /// Whether the folder with the segments [names], outermost first, is
  /// the tool's own or lies inside it.
  bool isInternalFolder(List<String> names) => _hasInternalName(names);

  static bool _hasInternalName(List<String> names) =>
      names.any(_internalNames.contains);

  /// Syncthing never syncs `.syncthing.*` files and deletes stale ones
  /// after a day, so a temp file left by a crash is cleaned up.
  ///
  /// The temp file name of an atomic write; [randomToken] keeps
  /// concurrent writes apart.
  String tempFileName(String randomToken) =>
      '.syncthing.truce-$randomToken.tmp';

  /// Syncthing's temp files: `.syncthing.*.tmp`, and `~syncthing~*.tmp`
  /// on Windows.
  static bool _isTempFile(String name) =>
      (name.startsWith('.syncthing.') || name.startsWith('~syncthing~')) &&
      name.endsWith('.tmp');
}
