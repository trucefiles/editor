import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  /// A finder over folders given as path → entry names; missing paths
  /// cannot be read.
  /// Parents are visible unless [hidden].
  SyncthingRootFinder finderOver(
    Map<String, Set<String>> folders, {
    bool hidden = false,
  }) => SyncthingRootFinder((path) async => folders[path], (_) => !hidden);

  test('finds the folder itself as the root', () async {
    final finder = finderOver({
      '/sync/notes': {'.stfolder', 'a.md'},
    });

    final found = await finder.find('/sync/notes');

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

    final found = await finder.find('/sync/notes/work');

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

    expect(await finder.find('/home/notes'), isA<SyncRootMissing>());
  });

  test('stops at the first parent it cannot read', () async {
    final finder = finderOver({
      '/storage/0/notes': {'a.md'},
      '/storage/0': {'notes'},
      '/': {'.stfolder'},
    });

    expect(await finder.find('/storage/0/notes'), isA<SyncRootMissing>());
  });

  test('unknown without visible parents and no marker', () async {
    final finder = finderOver({
      '/run/doc/notes': {'a.md'},
    }, hidden: true);

    expect(await finder.find('/run/doc/notes'), isA<SyncRootUnknown>());
  });

  test('found without visible parents if the folder is a root', () async {
    final finder = finderOver({
      '/run/doc/notes': {'.stfolder'},
    }, hidden: true);

    expect(await finder.find('/run/doc/notes'), isA<SyncRootFound>());
  });

  test('unknown if the folder itself cannot be read', () async {
    expect(await finderOver({}).find('/gone'), isA<SyncRootUnknown>());
  });
}
