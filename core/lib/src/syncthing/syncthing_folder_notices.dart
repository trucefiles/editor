import '../sync/folder_notices.dart';
import '../sync/sync_check.dart';

/// The notices of a Syncthing folder: whether Syncthing syncs it (from
/// [_syncCheck]), and, while [_pollInterval] gives one, that its changes
/// are polled at that interval because they can't be followed live.
final class SyncthingFolderNotices implements FolderNotices {
  const SyncthingFolderNotices(this._syncCheck, {this._pollInterval});

  final SyncCheck _syncCheck;

  /// Asked at each check, as live following can stop at any time.
  final Duration? Function()? _pollInterval;

  @override
  Future<List<FolderNotice>> check() async => [
    ...switch (await _syncCheck.check()) {
      SyncStatus.synced => const <FolderNotice>[],
      SyncStatus.notSynced => const [NotSyncedNotice()],
      SyncStatus.unknown => const [SyncUnknownNotice()],
    },
    if (_pollInterval?.call() case final interval?) PolledNotice(interval),
  ];
}
