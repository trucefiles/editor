import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late FakePlugin plugin;
  late FolderListOwner owner;
  late OpenFolders open;

  setUp(() async {
    plugin = FakePlugin();
    owner = folderListOwner(
      FolderListWork(
        store: FolderListStore(File('${tempFolder().path}/folders.json')),
        plugins: FolderPlugins([plugin]),
        secureOpen: (_, _) async {},
        forgetDrafts: (_) async {},
        countDrafts: (_) async => 0,
      ),
    );
    addTearDown(owner.close);
    open = OpenFolders(
      owner,
      plugins: FolderPlugins([plugin]),
      build: (folder, raw, reach) => folderServices(
        raw,
        reach: reach,
        handles: (_) => true,
        backupsPath: '${tempFolder().path}/backups',
        deviceId: 'phone',
        checkEvery: () => Duration.zero,
        wrote: (_) {},
      ),
    );
    addTearDown(open.close);
    await settledList(owner);
  });

  Future<Folder> added(String name) async {
    final answer = await ask<FolderListInput, FolderListAnswer>(
      owner.send,
      owner.events,
      (ticket) => AddFolders(
        ticket,
        plugin: 'fake',
        candidates: [
          (candidate: FakePlugin.candidate(name), name: name, color: 'teal'),
        ],
      ),
    );
    return (answer! as FoldersAdded).result.value.single;
  }

  test('opens a folder at the first ask, once', () async {
    final a = await added('a');
    plugin.folder('a').files.put('x.md', 'x');

    final services = open.servicesOf(a.id);

    expect(identical(open.servicesOf(a.id), services), isTrue);
    expect((await services.store.read(path('x.md'))).value.bytes, bytesOf('x'));
  });

  test('a folder that went is closed, and stays so', () async {
    final a = await added('a');
    final services = open.servicesOf(a.id);
    final closed = open.changes.first;

    await ask<FolderListInput, FolderListAnswer>(
      owner.send,
      owner.events,
      (ticket) => RemoveFolder(ticket, a),
    );
    await closed;
    await Future<void>.delayed(Duration.zero);

    expect(identical(open.servicesOf(a.id), services), isTrue);
    expect((await services.store.list()).error, StoreError.closed);
  });

  test('a folder never shown is a bug', () {
    expect(() => open.servicesOf(folderId('nope')), throwsStateError);
  });
}
