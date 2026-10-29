import 'package:truce_core/truce_core.dart';

import 'folder_backups.dart';

/// Compares a backup with its document as it is now, through [_restore];
/// [_rescan] scans after a keep.
final class RestoreCompare
    implements CompareSource<FolderBackup, RestoreChoice> {
  RestoreCompare(this._restore, this._rescan);

  final BackupRestore _restore;
  final Future<void> Function() _rescan;

  @override
  Future<Result<RestoreChoice, StoreError>> load(FolderBackup target) =>
      _restore.load(target.backup);

  @override
  Future<Result<void, ResolveError>> keep(
    FolderBackup target,
    RestoreChoice sides,
    Resolution choice,
  ) => _restore.keep(sides, choice);

  @override
  Future<void> rescan() => _rescan();
}
