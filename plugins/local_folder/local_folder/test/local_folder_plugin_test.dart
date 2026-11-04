import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_local_folder/truce_local_folder.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  group('the plugin', () {
    late Directory dir;
    late LocalDisk disk;
    late LocalFolderPlugin plugin;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('truce_local_plugin');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/Notes/deep').createSync(recursive: true);
      Directory('${dir.path}/.hidden/x').createSync(recursive: true);
      disk = LocalDisk(
        replacesInPlace: false,
        followsLive: (_) => false,
        seesParents: (_) => true,
        hostPaths: const SameHostPaths(),
      );
      plugin = LocalFolderPlugin(disk);
    });

    Uri at(String name) => Uri.file('${dir.path}/$name');

    test('offers any picked directory, named after it', () async {
      final candidate = (await plugin.candidateFor(at('Notes'))).value;

      expect(candidate.defaultName, 'Notes');
      expect(candidate.location, '${dir.path}/Notes');
    });

    test('refuses a pick inside a hidden folder', () async {
      expect(
        (await plugin.candidateFor(at('.hidden/x'))).error,
        LocalPickRefused.hidden,
      );
    });

    test('refuses a pick at, inside or around one added, '
        'and claims its folders', () async {
      plugin.add([(await plugin.candidateFor(at('Notes'))).value]);

      for (final name in ['Notes', 'Notes/deep']) {
        expect(
          (await plugin.candidateFor(at(name))).error,
          LocalPickRefused.overlaps,
        );
      }
      expect(disk.areas.clashes('syncthing', at('Notes/deep')), isTrue);
    });

    test('refuses a pick inside another plugin\'s area', () async {
      disk.areas.claim('syncthing', [at('Notes')]);

      expect(
        (await plugin.candidateFor(at('Notes/deep'))).error,
        LocalPickRefused.overlaps,
      );
    });

    test('keeps its state as a blob; forgets a folder', () async {
      final [notes] = plugin.add([
        (await plugin.candidateFor(at('Notes'))).value,
      ]).value;
      final again = LocalFolderPlugin(disk)..load(plugin.blob);
      expect(again.folders.single.location, notes.location);

      plugin.forget(notes.id);

      expect(plugin.folders, isEmpty);
      expect(disk.areas.clashes('syncthing', at('Notes')), isFalse);
      expect(plugin.load({'folders': 3}), isFalse);
    });

    test('a blob with a folder id unsafe as a file name is unreadable', () {
      expect(
        plugin.load({
          'folders': [
            {
              'id': '../x',
              'address': 'file:///home/me/Notes',
              'host': 'file:///home/me/Notes',
            },
          ],
        }),
        isFalse,
      );
      expect(plugin.folders, isEmpty);
    });

    test('writes atomically with its own temp files', () async {
      final [notes] = plugin.add([
        (await plugin.candidateFor(at('Notes'))).value,
      ]).value;

      await plugin.open(notes.id).files.create(path('a.md'), bytesOf('text'));

      expect(File('${dir.path}/Notes/a.md').readAsStringSync(), 'text');
    });
  });

  group('a folder', () {
    late MemoryFileStore store;
    late OpenFolder folder;

    setUp(() {
      store = MemoryFileStore()..put('todo.md', 'main');
      folder = LocalDirectory(LocalFolder(files: store, changes: null)).open(
        BoundedPlace(
          store,
          null,
          handles: (_) => true,
          checkEvery: () => Duration.zero,
        ),
      );
    });

    test(
      'keeps a save that cannot land as a copy, shown as a conflict',
      () async {
        await folder.conflicts.add(path('todo.md'), bytesOf('mine'));

        final scan = (await folder.scanner.scan()).value;
        expect(scan.files.map((file) => file.path), [path('todo.md')]);
        final copy = scan.conflicts.single.copies.single;
        expect(copy.id, startsWith('todo.truce-conflict-'));
        expect(
          String.fromCharCodes((await folder.conflicts.read(copy)).value),
          'mine',
        );
      },
    );

    test('hides its temp files, never lists them', () async {
      store.put('.truce-0123abcd.tmp', 'left by a crash');

      final scan = (await folder.scanner.scan()).value;

      expect(scan.files.map((file) => file.path), [path('todo.md')]);
    });

    test('tells nothing', () async {
      expect(await folder.notices.check(), isEmpty);
    });
  });

  test('conflict names round-trip and keep the extension', () {
    final names = LocalConflictNames();
    final name = names.format('plan.v2.txt', DateTime(2026, 10, 3, 13, 48, 9));

    expect(name, 'plan.v2.truce-conflict-20261003-134809.txt');
    expect(names.parse(name), (
      mainName: 'plan.v2.txt',
      createdAt: DateTime(2026, 10, 3, 13, 48, 9),
    ));
    expect(names.parse('plan.txt'), isNull);
  });
}
