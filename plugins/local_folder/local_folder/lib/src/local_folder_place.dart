import 'package:truce_core/truce_core.dart';

import 'local_conflict_names.dart';
import 'local_folder_rules.dart';

/// One local base folder, on [_local]: its files by the app's own rules.
final class LocalFolderPlace implements ToolPlace {
  const LocalFolderPlace(this._local);

  /// The file-name rules of a local folder.
  static const rules = LocalFolderRules();
  static const _names = LocalConflictNames();

  /// What the app shows of a local folder: no hidden files, none of its
  /// own.
  static final _shown = VisibleFileFilter(rules.isInternal);

  final LocalPlace _local;

  @override
  FileStore get files => _local.files;

  @override
  LiveChanges? get changes => _local.changes;

  @override
  SubfolderNames get subfolders => _local.subfolders.shownBy(showsFolder);

  @override
  bool showsFolder(RelPath folder) => _shown.includesFolderPath(folder);

  @override
  SyncedFolder open(BoundedPlace bounded) {
    final store = bounded.files;
    return SyncedFolder(
      store: store,
      scanner: NamedCopiesScanner(store, _shown, _names),
      conflicts: NamedConflictSource(store, _names),
      notices: const _NoNotices(),
      changes: bounded.changes,
    );
  }
}

/// No tool tells anything about a local folder.
final class _NoNotices implements FolderNotices {
  const _NoNotices();

  @override
  Future<List<FolderNotice>> check() async => const [];
}
