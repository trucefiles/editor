import 'package:truce_core/truce_core.dart';

import 'plain_conflict_names.dart';
import 'plain_folder_rules.dart';

/// One plain base folder, on [_local]: its files by the app's own rules.
final class PlainFolderPlace implements ToolPlace {
  const PlainFolderPlace(this._local);

  /// The file-name rules of a plain folder.
  static const rules = PlainFolderRules();
  static const _names = PlainConflictNames();

  /// What the app shows of a plain folder: no hidden files, none of its
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

/// No tool tells anything about a plain folder.
final class _NoNotices implements FolderNotices {
  const _NoNotices();

  @override
  Future<List<FolderNotice>> check() async => const [];
}
