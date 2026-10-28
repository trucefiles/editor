import 'package:truce_core/truce_core.dart';

/// The notices of a Syncthing folder: whether Syncthing syncs it (from
/// [_syncCheck]).
final class SyncthingFolderNotices implements FolderNotices {
  const SyncthingFolderNotices(this._syncCheck);

  final SyncCheck _syncCheck;

  @override
  Future<List<FolderNotice>> check() async =>
      switch (await _syncCheck.check()) {
        SyncStatus.synced => const [],
        SyncStatus.notSynced => const [NotSyncedNotice()],
        SyncStatus.unknown => const [SyncUnknownNotice()],
      };
}
