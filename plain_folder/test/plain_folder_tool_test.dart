import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_plain_folder/truce_plain_folder.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  group('the tool', () {
    late Directory dir;
    final tool = PlainFolderTool(
      LocalDisk(
        replacesInPlace: false,
        followsLive: (_) => false,
        seesParents: (_) => true,
      ),
    );

    setUp(() {
      dir = Directory.systemTemp.createTempSync('truce_plain_tool');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/.stfolder').createSync();
    });

    test('recognizes nothing on its own: the user picks it', () async {
      final address = Uri.file(dir.path);

      expect(await tool.recognize(address), SyncStatus.unknown);
      expect(await tool.missesOldVersions(address), isFalse);
      expect(tool.isToolFolder(Uri.file('${dir.path}/.stversions')), isFalse);
    });

    test('writes atomically with its own temp files', () async {
      final place = tool.place(Uri.file(dir.path));

      await place.files.create(path('a.md'), bytesOf('text'));

      expect(File('${dir.path}/a.md').readAsStringSync(), 'text');
    });

    test('shows no hidden folder, nor what is in it', () {
      final place = tool.place(Uri.file(dir.path));

      expect(place.showsFolder(path('docs/new')), isTrue);
      expect(place.showsFolder(path('.git')), isFalse);
      expect(place.showsFolder(path('.git/docs')), isFalse);
    });
  });

  group('a folder', () {
    late MemoryFileStore store;
    late SyncedFolder folder;

    setUp(() {
      store = MemoryFileStore()..put('todo.md', 'main');
      folder =
          PlainFolderPlace(
            LocalPlace(
              files: store,
              changes: null,
              subfolders: const LocalSubfolderNames('/none'),
              markers: const FakeFolderMarkers([{}]),
            ),
          ).open(
            BoundedPlace(
              store,
              null,
              const WholeFolder(),
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
    const names = PlainConflictNames();
    final name = names.format('plan.v2.txt', DateTime(2026, 10, 3, 13, 48, 9));

    expect(name, 'plan.v2.truce-conflict-20261003-134809.txt');
    expect(names.parse(name), (
      mainName: 'plan.v2.txt',
      createdAt: DateTime(2026, 10, 3, 13, 48, 9),
    ));
    expect(names.parse('plan.txt'), isNull);
  });
}
