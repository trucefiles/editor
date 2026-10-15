import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  Future<List<FolderNotice>> check(
    SyncStatus status, {
    Duration? pollInterval,
  }) => SyncthingFolderNotices(
    _FixedCheck(status),
    pollInterval: pollInterval,
  ).check();

  test('none for a synced folder', () async {
    expect(await check(SyncStatus.synced), isEmpty);
  });

  test('warns about a folder Syncthing does not sync', () async {
    final notices = await check(SyncStatus.notSynced);

    expect(notices, [isA<NotSyncedNotice>()]);
    expect(notices.single.isWarning, isTrue);
  });

  test('informs when syncing could not be checked', () async {
    final notices = await check(SyncStatus.unknown);

    expect(notices, [isA<SyncUnknownNotice>()]);
    expect(notices.single.isWarning, isFalse);
  });

  test('tells the interval when changes are polled', () async {
    final notices = await check(
      SyncStatus.notSynced,
      pollInterval: const Duration(seconds: 10),
    );

    expect(notices, [
      isA<NotSyncedNotice>(),
      const PolledNotice(Duration(seconds: 10)),
    ]);
  });
}

final class _FixedCheck implements SyncCheck {
  const _FixedCheck(this.status);

  final SyncStatus status;

  @override
  Future<SyncStatus> check() async => status;
}
