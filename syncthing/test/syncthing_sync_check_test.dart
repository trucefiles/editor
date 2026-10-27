import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';

void main() {
  /// A check of [folderPath] over folders given as path → entry names;
  /// missing paths cannot be read. Parents are visible unless [hidden].
  Future<SyncStatus> check(
    String folderPath,
    Map<String, Set<String>> folders, {
    bool hidden = false,
  }) => SyncthingSyncCheck(
    folderPath,
    readNames: (path) async => folders[path],
    parentsVisible: !hidden,
  ).check();

  test('synced if the folder itself is a root', () async {
    final status = await check('/sync/documents', {
      '/sync/documents': {'.stfolder', 'a.md'},
    });

    expect(status, SyncStatus.synced);
  });

  test('synced if a parent is a root', () async {
    final status = await check('/sync/documents/work', {
      '/sync/documents/work': {'a.md'},
      '/sync/documents': {'work'},
      '/sync': {'.stfolder', 'documents'},
    });

    expect(status, SyncStatus.synced);
  });

  test('not synced if no root up to the top', () async {
    final status = await check('/home/documents', {
      '/home/documents': {'a.md'},
      '/home': {'documents'},
      '/': {'home'},
    });

    expect(status, SyncStatus.notSynced);
  });

  test('stops at the first parent it cannot read', () async {
    final status = await check('/storage/0/documents', {
      '/storage/0/documents': {'a.md'},
      '/storage/0': {'documents'},
      '/': {'.stfolder'},
    });

    expect(status, SyncStatus.notSynced);
  });

  test('unknown without visible parents and no marker', () async {
    final status = await check('/run/doc/documents', {
      '/run/doc/documents': {'a.md'},
    }, hidden: true);

    expect(status, SyncStatus.unknown);
  });

  test('synced without visible parents if the folder is a root', () async {
    final status = await check('/run/doc/documents', {
      '/run/doc/documents': {'.stfolder'},
    }, hidden: true);

    expect(status, SyncStatus.synced);
  });

  test('unknown if the folder itself cannot be read', () async {
    expect(await check('/gone', {}), SyncStatus.unknown);
  });
}
