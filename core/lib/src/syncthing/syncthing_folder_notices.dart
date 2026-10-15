import '../sync/folder_notices.dart';
import '../sync/sync_check.dart';

/// The notices of a Syncthing folder: whether Syncthing syncs it (from
/// [_syncCheck]), and, given a [_pollInterval], that its changes are polled
/// because they can't be followed live.
final class SyncthingFolderNotices implements FolderNotices {
  const SyncthingFolderNotices(this._syncCheck, {this._pollInterval});

  final SyncCheck _syncCheck;
  final Duration? _pollInterval;

  @override
  Future<List<FolderNotice>> check() async => [
    ...switch (await _syncCheck.check()) {
      SyncStatus.synced => const <FolderNotice>[],
      SyncStatus.notSynced => const [NotSyncedNotice()],
      SyncStatus.unknown => const [SyncUnknownNotice()],
    },
    if (_pollInterval case final interval?) PolledNotice(interval),
  ];
}
