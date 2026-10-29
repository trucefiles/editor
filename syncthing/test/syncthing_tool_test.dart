import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const copy = 'todo.sync-conflict-20261003-134809-4I343AW.md';

  group('the tool', () {
    late Directory dir;
    final tool = SyncthingTool(
      LocalDisk(
        replacesInPlace: false,
        followsLive: (_) => false,
        seesParents: (_) => true,
      ),
    );

    setUp(() {
      dir = Directory.systemTemp.createTempSync('truce_syncthing_tool');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/synced/docs').createSync(recursive: true);
      Directory('${dir.path}/synced/.stversions').createSync();
      Directory('${dir.path}/synced/.git').createSync();
      File('${dir.path}/synced/.stfolder').createSync();
      Directory('${dir.path}/plain').createSync();
    });

    Uri at(String name) => Uri.file('${dir.path}/$name');

    test('recognizes a folder at or below a Syncthing folder', () async {
      expect(await tool.recognize(at('synced')), SyncStatus.synced);
      expect(await tool.recognize(at('synced/docs')), SyncStatus.synced);
      expect(await tool.recognize(at('plain')), SyncStatus.notSynced);
    });

    test('misses old versions only below the Syncthing folder', () async {
      expect(await tool.missesOldVersions(at('synced/docs')), isTrue);
      expect(await tool.missesOldVersions(at('synced')), isFalse);
      expect(await tool.missesOldVersions(at('plain')), isFalse);
    });

    test("doesn't know an address it can't open", () async {
      final elsewhere = Uri.parse('fake://cloud/notes');

      expect(await tool.recognize(elsewhere), SyncStatus.unknown);
      expect(await tool.missesOldVersions(elsewhere), isFalse);
    });

    test('knows its own folders', () {
      expect(tool.isToolFolder(['.stversions']), isTrue);
      expect(tool.isToolFolder(['docs']), isFalse);
    });

    test('works on the folder at an address with its temp files, '
        'offering only the folders it shows', () async {
      final place = tool.place(at('synced'));

      await place.files.create(path('a.md'), bytesOf('text'));

      expect(File('${dir.path}/synced/a.md').readAsStringSync(), 'text');
      expect((await place.subfolders.namesIn(null)).value, ['docs']);
    });

    test('shows no hidden folder and none of its own, nor what is in them', () {
      final place = tool.place(at('synced'));

      expect(place.showsFolder(path('docs/new')), isTrue);
      expect(place.showsFolder(path('.stversions')), isFalse);
      expect(place.showsFolder(path('.stversions/docs')), isFalse);
      expect(place.showsFolder(path('docs/.git')), isFalse);
    });
  });

  group('a folder', () {
    late MemoryFileStore store;
    late SyncedFolder folder;
    final live = _Hints();

    setUp(() {
      store = MemoryFileStore()
        ..put('todo.md', 'main')
        ..put(copy, 'theirs');
      folder = SyncthingPlace(
        LocalPlace(
          files: store,
          changes: null,
          subfolders: const LocalSubfolderNames('/none'),
          markers: const FakeFolderMarkers([
            {'.stfolder'},
          ]),
        ),
      ).open(_bounded(store, live));
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

    test('drops changes in its own folders', () async {
      live.hints = [
        PathChanged(path('.stversions/todo~20261003-134809.md')),
        PathChanged(path(copy)),
        const ListAgain(),
      ];

      expect(await folder.changes!.changes.take(2).toList(), [
        PathChanged(path(copy)),
        const ListAgain(),
      ]);
    });

    test('tells whether Syncthing syncs it', () async {
      expect(await folder.notices.check(), isEmpty);
    });
  });
}

/// All of [store] and [live], as the app bounds them for a whole folder.
BoundedPlace _bounded(FileStore store, LiveChanges? live) => BoundedPlace(
  store,
  live,
  const WholeFolder(),
  handles: (_) => true,
  checkEvery: () => Duration.zero,
);

/// Changes that give [hints], then end.
final class _Hints implements LiveChanges {
  List<ChangeHint> hints = const [];

  @override
  Stream<ChangeHint> below(RelPath? folder) => Stream.fromIterable(hints);
}
