import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import '../file_arrival.dart';
import 'folder_backups.dart';

/// Compares a backup with its file as it is now, through [_restore];
/// [_rescan] scans after a keep. What is kept arrives at the file's
/// place first, as its type says ([FileArrivals.restored]).
final class RestoreCompare
    implements CompareSource<FolderBackup, RestoreChoice> {
  RestoreCompare(this._restore, this._rescan, {required this._arrivals});

  final BackupRestore _restore;
  final Future<void> Function() _rescan;
  final FileArrivals _arrivals;

  @override
  Future<Result<RestoreChoice, StoreError>> load(FolderBackup target) =>
      _restore.load(target.backup);

  @override
  Future<Result<void, ResolveError>> keep(
    FolderBackup target,
    RestoreChoice sides,
    Resolution choice,
  ) async {
    Future<Uint8List> arrived(Uint8List bytes) => _arrivals.restored(
      bytes,
      folder: target.folder,
      from: target.backup.filePath,
    );

    return switch (choice) {
      KeepCurrent() => _restore.keep(sides, choice),
      KeepOther() => _restore.keep(
        RestoreChoice(
          sides.backup,
          bytes: await arrived(sides.bytes),
          current: sides.current,
        ),
        choice,
      ),
      KeepMerged(:final bytes) => _restore.keep(
        sides,
        KeepMerged(await arrived(bytes)),
      ),
    };
  }

  @override
  Future<void> rescan() => _rescan();
}
