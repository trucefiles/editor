import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  /// A check of a base folder whose [levels] hold these entry names, the
  /// base folder first; `null` cannot be read. Parents are visible unless
  /// [hidden].
  Future<SyncStatus> check(List<Set<String>?> levels, {bool hidden = false}) =>
      SyncthingSyncCheck(FakeFolderMarkers(levels, seesParents: !hidden))
          .check();

  test('synced if the folder itself is a root', () async {
    expect(
      await check([
        {'.stfolder', 'a.md'},
      ]),
      SyncStatus.synced,
    );
  });

  test('synced if a parent is a root', () async {
    final status = await check([
      {'a.md'},
      {'work'},
      {'.stfolder', 'documents'},
    ]);

    expect(status, SyncStatus.synced);
  });

  test('not synced if no root up to the top', () async {
    final status = await check([
      {'a.md'},
      {'documents'},
      {'home'},
    ]);

    expect(status, SyncStatus.notSynced);
  });

  test('stops at the first parent it cannot read', () async {
    final status = await check([
      {'a.md'},
      null,
      {'.stfolder'},
    ]);

    expect(status, SyncStatus.notSynced);
  });

  test('unknown without visible parents and no marker', () async {
    expect(
      await check([
        {'a.md'},
      ], hidden: true),
      SyncStatus.unknown,
    );
  });

  test('synced without visible parents if the folder is a root', () async {
    expect(
      await check([
        {'.stfolder'},
      ], hidden: true),
      SyncStatus.synced,
    );
  });

  test('unknown if the folder itself cannot be read', () async {
    expect(await check([null]), SyncStatus.unknown);
  });
}
