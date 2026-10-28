import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_plain_folder/truce_plain_folder.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const tool = PlainFolderTool();

  test('recognizes nothing on its own: the user picks it', () async {
    final markers = FakeFolderMarkers(const [
      {'.stfolder'},
    ]);

    expect(await tool.recognize(markers), SyncStatus.unknown);
    expect(await tool.missesOldVersions(markers), isFalse);
  });

  group('a folder', () {
    late MemoryFileStore store;
    late SyncedFolder folder;
    Duration? polled;

    setUp(() {
      polled = null;
      store = MemoryFileStore()..put('todo.md', 'main');
      folder = tool.open(
        store,
        shown: const DefaultFileFilter(PlainFolderRules(), fakeFileTypes),
        markers: const FakeFolderMarkers([{}]),
        pollInterval: () => polled,
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
      expect(
        folder.followed.includesFile(path('.truce-0123abcd.tmp')),
        isFalse,
      );
    });

    test('tells only that it polls, while it does', () async {
      expect(await folder.notices.check(), isEmpty);
      polled = const Duration(minutes: 1);
      expect(await folder.notices.check(), [
        const PolledNotice(Duration(minutes: 1)),
      ]);
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
