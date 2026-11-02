import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';

void main() {
  Future<List<FolderNotice>> check(SyncStatus status) =>
      SyncthingFolderNotices(_FixedCheck(status)).check();

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
}

final class _FixedCheck implements SyncCheck {
  const _FixedCheck(this.status);

  final SyncStatus status;

  @override
  Future<SyncStatus> check() async => status;
}
