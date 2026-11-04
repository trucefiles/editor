import 'package:truce_core/truce_core.dart';

import 'local_conflict_names.dart';

/// The file-name rules of a local folder: the app's own temp files and
/// conflict copies ([LocalConflictNames]); no folders of a tool.
///
/// Temp files a crash leaves (`.truce-*.tmp`) are hidden but never cleaned
/// up: deleting them would be a write into the folder that no user action
/// asked for, and an unknown sync tool may sync them.
final class LocalFolderRules {
  const LocalFolderRules();

  static const _tempPrefix = '.truce-';
  static final _copyNames = LocalConflictNames();
  static const _tempSuffix = '.tmp';

  /// Whether [path] belongs to the sync tool itself (folder markers,
  /// version folders, temp files, conflict copies): never shown.
  bool isInternal(RelPath path) =>
      _isTempFile(path.name) || _copyNames.parse(path.name) != null;

  /// The temp file name of an atomic write; [randomToken] keeps
  /// concurrent writes apart.
  String tempFileName(String randomToken) =>
      '$_tempPrefix$randomToken$_tempSuffix';

  static bool _isTempFile(String name) =>
      name.startsWith(_tempPrefix) && name.endsWith(_tempSuffix);
}
