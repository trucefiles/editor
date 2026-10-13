import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  /// A finder over folders given as path → entry names; missing paths
  /// cannot be read.
  SyncthingRootFinder finderOver(Map<String, Set<String>> folders) =>
      SyncthingRootFinder((path) async => folders[path]);

  test('finds the folder itself as the root', () async {
    final finder = finderOver({
      '/sync/notes': {'.stfolder', 'a.md'},
    });

    final found = await finder.find('/sync/notes', parentsVisible: true);

    expect(
      found,
      isA<SyncRootFound>().having((f) => f.rootPath, 'root', '/sync/notes'),
    );
  });

  test('finds a parent as the root', () async {
    final finder = finderOver({
      '/sync/notes/work': {'a.md'},
      '/sync/notes': {'work'},
      '/sync': {'.stfolder', 'notes'},
    });

    final found = await finder.find('/sync/notes/work', parentsVisible: true);

    expect(
      found,
      isA<SyncRootFound>().having((f) => f.rootPath, 'root', '/sync'),
    );
  });

  test('missing if no root up to the top', () async {
    final finder = finderOver({
      '/home/notes': {'a.md'},
      '/home': {'notes'},
      '/': {'home'},
    });

    expect(
      await finder.find('/home/notes', parentsVisible: true),
      isA<SyncRootMissing>(),
    );
  });

  test('stops at the first parent it cannot read', () async {
    final finder = finderOver({
      '/storage/0/notes': {'a.md'},
      '/storage/0': {'notes'},
      '/': {'.stfolder'},
    });

    expect(
      await finder.find('/storage/0/notes', parentsVisible: true),
      isA<SyncRootMissing>(),
    );
  });

  test('unknown without visible parents and no marker', () async {
    final finder = finderOver({
      '/run/doc/notes': {'a.md'},
    });

    expect(
      await finder.find('/run/doc/notes', parentsVisible: false),
      isA<SyncRootUnknown>(),
    );
  });

  test('found without visible parents if the folder is a root', () async {
    final finder = finderOver({
      '/run/doc/notes': {'.stfolder'},
    });

    expect(
      await finder.find('/run/doc/notes', parentsVisible: false),
      isA<SyncRootFound>(),
    );
  });

  test('unknown if the folder itself cannot be read', () async {
    expect(
      await finderOver({}).find('/gone', parentsVisible: true),
      isA<SyncRootUnknown>(),
    );
  });
}
