import 'package:truce_core/truce_core.dart';

import 'plain_conflict_names.dart';
import 'plain_folder_rules.dart';

/// One plain base folder, on [_local]: its files by the app's own rules.
final class PlainFolderPlace implements ToolPlace {
  const PlainFolderPlace(this._local);

  /// The file-name rules of a plain folder.
  static const rules = PlainFolderRules();
  static const _names = PlainConflictNames();

  final LocalPlace _local;

  @override
  FileStore get files => _local.files;

  @override
  LiveChanges? get changes => _local.changes;

  @override
  SubfolderNames get subfolders => _local.subfolders;

  @override
  SyncedFolder open(
    FileStore store, {
    required FolderChanges? changes,
    required FileTypeDetector types,
  }) {
    final shown = DefaultFileFilter(rules, types);
    return SyncedFolder(
      store: store,
      scanner: NamedCopiesScanner(store, shown, _names),
      conflicts: NamedConflictSource(store, _names),
      notices: const _NoNotices(),
      changes: changes,
      shown: shown,
    );
  }
}

/// No tool tells anything about a plain folder.
final class _NoNotices implements FolderNotices {
  const _NoNotices();

  @override
  Future<List<FolderNotice>> check() async => const [];
}
