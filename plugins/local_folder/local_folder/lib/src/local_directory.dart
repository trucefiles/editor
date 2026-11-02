import 'package:truce_core/truce_core.dart';

import 'local_conflict_names.dart';
import 'local_folder_rules.dart';

/// One local folder, on [_local], its directory: its files by the app's
/// own rules.
final class LocalDirectory implements RawFolder {
  const LocalDirectory(this._local);

  /// The file-name rules of a local folder.
  static const rules = LocalFolderRules();
  static const _names = LocalConflictNames();

  /// What the app shows of a local folder: no hidden files, none of its
  /// own.
  static final _shown = VisibleFileFilter(rules.isInternal);

  final LocalFolder _local;

  @override
  FileStore get files => _local.files;

  @override
  LiveChanges? get changes => _local.changes;

  @override
  OpenFolder open(BoundedPlace bounded) {
    final store = bounded.files;
    return OpenFolder(
      bounded,
      store: store,
      scanner: NamedCopiesScanner(store, _shown, _names),
      showsFolder: _shown.includesFolderPath,
      conflicts: NamedConflictSource(store, _names),
      notices: const _NoNotices(),
      changes: bounded.changes,
    );
  }
}

/// Nothing to tell about a local folder.
final class _NoNotices implements FolderNotices {
  const _NoNotices();

  @override
  Future<List<FolderNotice>> check() async => const [];
}
