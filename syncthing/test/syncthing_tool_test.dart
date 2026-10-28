import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const tool = SyncthingTool();
  const copy = 'todo.sync-conflict-20261003-134809-4I343AW.md';

  test('recognizes a folder at or below a Syncthing folder', () async {
    expect(
      await tool.recognize(
        const FakeFolderMarkers([
          {},
          {'.stfolder'},
        ]),
      ),
      SyncStatus.synced,
    );
    expect(
      await tool.recognize(const FakeFolderMarkers([{}, {}])),
      SyncStatus.notSynced,
    );
  });

  test('misses old versions only below the Syncthing folder', () async {
    expect(
      await tool.missesOldVersions(
        const FakeFolderMarkers([
          {},
          {'.stfolder'},
        ]),
      ),
      isTrue,
    );
    expect(
      await tool.missesOldVersions(
        const FakeFolderMarkers([
          {'.stfolder'},
        ]),
      ),
      isFalse,
    );
    expect(
      await tool.missesOldVersions(const FakeFolderMarkers([{}, {}])),
      isFalse,
    );
  });

  group('a folder', () {
    late MemoryFileStore store;
    late SyncedFolder folder;

    setUp(() {
      store = MemoryFileStore()
        ..put('todo.md', 'main')
        ..put(copy, 'theirs');
      folder = tool.open(
        store,
        shown: const DefaultFileFilter(SyncthingAdapter(), fakeFileTypes),
        markers: const FakeFolderMarkers([
          {'.stfolder'},
        ]),
        pollInterval: () => null,
      );
    });

    test('shows documents with their conflict copies apart', () async {
      final scan = (await folder.scanner.scan()).value;

      expect(scan.files.map((file) => file.path), [path('todo.md')]);
      expect(scan.conflicts.single.copies.single.id, copy);
    });

    test('keeps a copy it adds as a Syncthing conflict copy', () async {
      await folder.conflicts.add(path('todo.md'), bytesOf('mine'));

      final scan = (await folder.scanner.scan()).value;
      expect(scan.conflicts.single.copies, hasLength(2));
    });

    test('follows documents and their conflict copies', () {
      expect(folder.followed.includesFile(path(copy)), isTrue);
      expect(folder.followed.includesFile(path('.stfolder')), isFalse);
    });

    test('tells whether Syncthing syncs it', () async {
      expect(await folder.notices.check(), isEmpty);
    });
  });
}
