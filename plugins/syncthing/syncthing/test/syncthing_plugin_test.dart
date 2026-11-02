import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const copy = 'todo.sync-conflict-20261003-134809-4I343AW.md';

  group('the plugin', () {
    late Directory dir;
    late LocalDisk disk;
    late SyncthingPlugin plugin;
    var ids = 0;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('truce_syncthing_plugin');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/Sync/docs/deep').createSync(recursive: true);
      Directory('${dir.path}/Sync/.stversions').createSync();
      Directory('${dir.path}/Sync/.git').createSync();
      File('${dir.path}/Sync/.stfolder').createSync();
      Directory('${dir.path}/plain').createSync();
      disk = LocalDisk(
        replacesInPlace: false,
        followsLive: (_) => false,
        seesParents: (_) => true,
        hostPaths: const SameHostPaths(),
      );
      ids = 0;
      plugin = SyncthingPlugin(disk, newId: () => 'id${ids++}');
    });

    Uri at(String name) => Uri.file('${dir.path}/$name');

    Future<PluginFolderCandidate> pick(String name) async {
      final found = await plugin.findRoot(at(name)) as RootFound;
      return plugin.candidate(found.root, found.rootHost, found.pick);
    }

    test('finds the root upward from a pick', () async {
      final found = await plugin.findRoot(at('Sync/docs/deep')) as RootFound;

      expect(found.root, at('Sync'));
      expect(found.pick, path('docs/deep'));
      expect(await plugin.findRoot(at('plain')), isA<RootNotFound>());
    });

    test('offers only the folders Syncthing shows in a root', () async {
      expect((await plugin.subfoldersOf(at('Sync')).namesIn(null)).value, [
        'docs',
      ]);
      expect(plugin.shows(path('.stversions')), isFalse);
    });

    test('adds folders in one root, refusing nested ones', () async {
      final docs = await pick('Sync/docs');

      final added = plugin.add([docs]).value.single;

      expect(added.location, contains('Syncthing folder Sync'));
      expect(plugin.takenIn(at('Sync')), {path('docs')});
      expect(
        plugin.add([await pick('Sync/docs/deep')]).error,
        AddRefused.overlaps,
      );
      expect(plugin.add([await pick('Sync')]).error, AddRefused.overlaps);
    });

    test('a pick inside a known root is found by it, also unseen', () async {
      plugin.add([await pick('Sync/docs')]);
      final blind = SyncthingPlugin(
        LocalDisk(
          replacesInPlace: false,
          followsLive: (_) => false,
          seesParents: (_) => false,
          hostPaths: const SameHostPaths(),
        ),
      )..load(plugin.blob);

      final found = await blind.findRoot(at('Sync/other')) as RootFound;

      expect(found.root, at('Sync'));
      expect(found.pick, path('other'));
    });

    test('claims its roots; another plugin can not add inside', () async {
      plugin.add([await pick('Sync/docs')]);

      expect(disk.areas.clashes('local', at('Sync/x')), isTrue);
      expect(disk.areas.clashes('local', at('plain')), isFalse);
    });

    test('names the root a new root would lie around', () async {
      // As "continue with this folder" adds a pick as its own root.
      plugin.add([plugin.candidate(at('Sync/docs'), at('Sync/docs'), null)]);

      expect(plugin.rootClash(at('Sync')), at('Sync/docs'));
      expect(plugin.rootClash(at('Sync/docs')), isNull, reason: 'same root');
      expect(plugin.rootClash(at('plain')), isNull);
    });

    test('a root goes with its last folder', () async {
      final [docs] = plugin.add([await pick('Sync/docs')]).value;

      plugin.forget(docs.id);

      expect(plugin.folders, isEmpty);
      expect(plugin.takenIn(at('Sync')), isEmpty);
      expect(disk.areas.clashes('local', at('Sync/x')), isFalse);
    });

    test('keeps its state as a blob, read back the same', () async {
      plugin.add([await pick('Sync/docs'), await pick('Sync')]);
      expect(plugin.add([]).value, isEmpty);

      final again = SyncthingPlugin(disk)..load(plugin.blob);

      expect(
        again.folders.map((folder) => folder.location),
        plugin.folders.map((folder) => folder.location),
      );
    });

    test('an unreadable blob holds no folders and claims nothing', () async {
      plugin.add([await pick('Sync/docs')]);

      expect(plugin.load({'roots': 'no'}), isFalse);

      expect(plugin.folders, isEmpty);
      expect(disk.areas.clashes('local', at('Sync')), isFalse);
    });

    test('a blob with a folder id unsafe as a file name is unreadable', () {
      expect(
        plugin.load({
          'roots': [
            {'id': 'r1', 'address': 'file:///s', 'host': 'file:///s'},
          ],
          'folders': [
            {'id': 'A/B', 'root': 'r1'},
          ],
        }),
        isFalse,
      );
    });

    test('opens a folder at its directory, with its temp files', () async {
      final [docs] = plugin.add([await pick('Sync/docs')]).value;

      await plugin.open(docs.id).files.create(path('a.md'), bytesOf('text'));

      expect(File('${dir.path}/Sync/docs/a.md').readAsStringSync(), 'text');
    });

    test('tells from the root whether Syncthing syncs a folder', () async {
      final [docs] = plugin.add([await pick('Sync/docs')]).value;
      final open = plugin.open(docs.id).open(_bounded(MemoryFileStore(), null));

      expect(await open.notices.check(), isEmpty);
    });
  });

  group('a folder', () {
    late MemoryFileStore store;
    late OpenFolder folder;
    final live = _Hints();

    setUp(() {
      store = MemoryFileStore()
        ..put('todo.md', 'main')
        ..put(copy, 'theirs');
      folder = SyncthingFolder(
        LocalFolder(files: store, changes: null),
        const FakeFolderMarkers([
          {'.stfolder'},
        ]),
      ).open(_bounded(store, live));
    });

    test('shows files with their conflict copies apart', () async {
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

    test('once closed, refuses everything', () async {
      await folder.close();

      expect(
        (await folder.store.read(path('todo.md'))).error,
        StoreError.closed,
      );
    });
  });
}

/// All of [store] and [live], as the app bounds them.
BoundedPlace _bounded(FileStore store, LiveChanges? live) => BoundedPlace(
  store,
  live,
  handles: (_) => true,
  checkEvery: () => Duration.zero,
);

/// Changes that give [hints], then end.
final class _Hints implements LiveChanges {
  List<ChangeHint> hints = const [];

  @override
  Stream<ChangeHint> follow() => Stream.fromIterable(hints);
}
