import 'package:truce_core/truce_core.dart';

import 'plain_conflict_names.dart';

/// The file-name rules of a plain folder: the app's own temp files and
/// conflict copies ([PlainConflictNames]); no folders of a tool.
///
/// Temp files a crash leaves (`.truce-*.tmp`) are hidden but never cleaned
/// up: deleting them would be a write into the folder that no user action
/// asked for, and an unknown sync tool may sync them.
final class PlainFolderRules implements SyncAdapter {
  const PlainFolderRules();

  static const _tempPrefix = '.truce-';
  static const _tempSuffix = '.tmp';

  @override
  String get name => 'Plain folder';

  @override
  bool isInternal(RelPath path) =>
      _isTempFile(path.name) ||
      const PlainConflictNames().parse(path.name) != null;

  @override
  bool isInternalFolder(List<String> names) => false;

  @override
  String tempFileName(String randomToken) =>
      '$_tempPrefix$randomToken$_tempSuffix';

  static bool _isTempFile(String name) =>
      name.startsWith(_tempPrefix) && name.endsWith(_tempSuffix);
}
