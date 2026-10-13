import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  /// A check over folders given as path → entry names; missing paths
  /// cannot be read.
  SyncCoverageCheck checkOver(Map<String, Set<String>> folders) =>
      SyncCoverageCheck(
        const SyncthingAdapter(),
        (path) async => folders[path],
      );

  test('synced if the folder is a Syncthing root', () async {
    final check = checkOver({
      '/sync/notes': {'.stfolder', 'a.md'},
    });

    expect(
      await check.check('/sync/notes', parentsVisible: true),
      SyncCoverage.synced,
    );
  });

  test('synced if a parent is a Syncthing root', () async {
    final check = checkOver({
      '/sync/notes/work': {'a.md'},
      '/sync/notes': {'work'},
      '/sync': {'.stfolder', 'notes'},
    });

    expect(
      await check.check('/sync/notes/work', parentsVisible: true),
      SyncCoverage.synced,
    );
  });

  test('not synced if no root is found up to the top', () async {
    final check = checkOver({
      '/home/notes': {'a.md'},
      '/home': {'notes'},
      '/': {'home'},
    });

    expect(
      await check.check('/home/notes', parentsVisible: true),
      SyncCoverage.notSynced,
    );
  });

  test('stops at the first parent it cannot read', () async {
    final check = checkOver({
      '/storage/0/notes': {'a.md'},
      '/storage/0': {'notes'},
      '/': {'.stfolder'},
    });

    expect(
      await check.check('/storage/0/notes', parentsVisible: true),
      SyncCoverage.notSynced,
    );
  });

  test('unknown without visible parents and no marker', () async {
    final check = checkOver({
      '/run/doc/notes': {'a.md'},
    });

    expect(
      await check.check('/run/doc/notes', parentsVisible: false),
      SyncCoverage.unknown,
    );
  });

  test('synced without visible parents if the folder is a root', () async {
    final check = checkOver({
      '/run/doc/notes': {'.stfolder'},
    });

    expect(
      await check.check('/run/doc/notes', parentsVisible: false),
      SyncCoverage.synced,
    );
  });

  test('unknown if the folder itself cannot be read', () async {
    expect(
      await checkOver({}).check('/gone', parentsVisible: true),
      SyncCoverage.unknown,
    );
  });

  test('reads local folder names; null if unreadable', () async {
    final dir = Directory.systemTemp.createTempSync('truce_names');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/.stfolder').createSync();
    File('${dir.path}/a.md').writeAsStringSync('');

    expect(await readLocalFolderNames(dir.path), {'.stfolder', 'a.md'});
    expect(await readLocalFolderNames('${dir.path}/missing'), isNull);
  });
}
