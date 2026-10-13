import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

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
    final status = await check('/sync/notes', {
      '/sync/notes': {'.stfolder', 'a.md'},
    });

    expect(status, SyncStatus.synced);
  });

  test('synced if a parent is a root', () async {
    final status = await check('/sync/notes/work', {
      '/sync/notes/work': {'a.md'},
      '/sync/notes': {'work'},
      '/sync': {'.stfolder', 'notes'},
    });

    expect(status, SyncStatus.synced);
  });

  test('not synced if no root up to the top', () async {
    final status = await check('/home/notes', {
      '/home/notes': {'a.md'},
      '/home': {'notes'},
      '/': {'home'},
    });

    expect(status, SyncStatus.notSynced);
  });

  test('stops at the first parent it cannot read', () async {
    final status = await check('/storage/0/notes', {
      '/storage/0/notes': {'a.md'},
      '/storage/0': {'notes'},
      '/': {'.stfolder'},
    });

    expect(status, SyncStatus.notSynced);
  });

  test('unknown without visible parents and no marker', () async {
    final status = await check('/run/doc/notes', {
      '/run/doc/notes': {'a.md'},
    }, hidden: true);

    expect(status, SyncStatus.unknown);
  });

  test('synced without visible parents if the folder is a root', () async {
    final status = await check('/run/doc/notes', {
      '/run/doc/notes': {'.stfolder'},
    }, hidden: true);

    expect(status, SyncStatus.synced);
  });

  test('unknown if the folder itself cannot be read', () async {
    expect(await check('/gone', {}), SyncStatus.unknown);
  });
}
