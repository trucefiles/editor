import 'package:truce_core/truce_core.dart';

import '../linked_files.dart';
import 'folder_backups.dart';

/// Compares a backup with its file as it is now, through [_restore];
/// [_rescan] scans after a keep. A kept backup's linked files come back
/// first ([LinkedFiles.bringBack]).
final class RestoreCompare
    implements CompareSource<FolderBackup, RestoreChoice> {
  RestoreCompare(
    this._restore,
    this._rescan, {
    this._linked = const NoLinkedFiles(),
  });

  final BackupRestore _restore;
  final Future<void> Function() _rescan;
  final LinkedFiles _linked;

  @override
  Future<Result<RestoreChoice, StoreError>> load(FolderBackup target) =>
      _restore.load(target.backup);

  @override
  Future<Result<void, ResolveError>> keep(
    FolderBackup target,
    RestoreChoice sides,
    Resolution choice,
  ) async {
    final kept = switch (choice) {
      KeepCurrent() => null,
      KeepOther() => sides.bytes,
      KeepMerged(:final bytes) => bytes,
    };
    if (kept != null) {
      if (TextFile.decode(kept) case final file?) {
        await _linked.bringBack(file.text, target.folder);
      }
    }
    return _restore.keep(sides, choice);
  }

  @override
  Future<void> rescan() => _rescan();
}
