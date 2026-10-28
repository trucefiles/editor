import 'package:truce_core/truce_core.dart';

import 'plain_conflict_names.dart';

/// The file-name rules of a plain folder: the app's own temp files and
/// conflict copies ([PlainConflictNames]); no folders of a tool.
///
/// Temp files a crash leaves (`.truce-*.tmp`) are hidden but never cleaned
/// up: deleting them would be a write into the folder that no user action
/// asked for, and an unknown sync tool may sync them.
final class PlainFolderRules {
  const PlainFolderRules();

  static const _tempPrefix = '.truce-';
  static const _tempSuffix = '.tmp';

  /// Whether [path] belongs to the sync tool itself (folder markers,
  /// version folders, temp files, conflict copies): never shown.
  bool isInternal(RelPath path) =>
      _isTempFile(path.name) ||
      const PlainConflictNames().parse(path.name) != null;

  /// Whether the folder with the segments [names], outermost first, is
  /// the tool's own or lies inside it.
  bool isInternalFolder(List<String> names) => false;

  /// The temp file name of an atomic write; [randomToken] keeps
  /// concurrent writes apart.
  String tempFileName(String randomToken) =>
      '$_tempPrefix$randomToken$_tempSuffix';

  static bool _isTempFile(String name) =>
      name.startsWith(_tempPrefix) && name.endsWith(_tempSuffix);
}
