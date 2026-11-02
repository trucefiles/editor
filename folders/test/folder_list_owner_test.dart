import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late File file;
  late FakePlugin plugin;
  late List<String> calls;
  late Map<FolderId, int> drafts;

  setUp(() {
    file = File('${tempFolder().path}/settings/folders.json');
    plugin = FakePlugin();
    calls = [];
    drafts = {};
  });

  FolderListOwner owner({FolderListStore? store}) {
    final owner = folderListOwner(
      FolderListWork(
        store: store ?? FolderListStore(file),
        plugins: FolderPlugins([plugin]),
        secureOpen: (id, reason) async =>
            calls.add('secure $id ${reason.name}'),
        forgetDrafts: (id) async => calls.add('forget $id'),
        countDrafts: (id) async {
          calls.add('count $id');
          return drafts[id] ?? 0;
        },
      ),
    );
    addTearDown(owner.close);
    return owner;
  }

  Future<A> asked<A extends FolderListAnswer>(
    FolderListOwner owner,
    FolderListAsking Function(Ticket ticket) input,
  ) async =>
      (await ask<FolderListInput, FolderListAnswer>(
            owner.send,
            owner.events,
            input,
          ))!
          as A;

  Future<Result<List<Folder>, FolderError>> add(
    FolderListOwner owner,
    List<String> names,
  ) async => (await asked<FoldersAdded>(
    owner,
    (ticket) => AddFolders(
      ticket,
      plugin: 'fake',
      candidates: [
        for (final name in names)
          (
            candidate: FakePlugin.candidate(name),
            name: name.toUpperCase(),
            color: 'teal',
          ),
      ],
    ),
  )).result;

  test('adds folders from a plugin, saved with its state', () async {
    final first = owner();
    await settledList(first);

    final added = (await add(first, ['a', 'b'])).value;

    expect(added.map((folder) => folder.id), [folderId('a'), folderId('b')]);
    expect(added.first.name, 'A');
    expect(added.first.location, 'fake:a');
    plugin = FakePlugin();
    expect(await settledFolders(owner()), added);
    expect(plugin.folders.map((folder) => folder.id), ['a', 'b']);
  });

  test('a plugin refusal adds nothing', () async {
    final folders = owner();
    await add(folders, ['a']);

    expect((await add(folders, ['b', 'a'])).error, FolderError.overlaps);
    expect((folders.state as FoldersLoaded).folders, hasLength(1));
    expect(plugin.folders, hasLength(1));
  });

  test('a failed save changes nothing, the plugin included', () async {
    final folders = owner(store: _FailingSave(FolderListStore(file)));
    await settledList(folders);

    expect((await add(folders, ['a'])).error, FolderError.notSaved);
    expect((folders.state as FoldersLoaded).folders, isEmpty);
    expect(plugin.folders, isEmpty);
  });

  test('renames and recolors, saved for the next start', () async {
    final folders = owner();
    final [a] = (await add(folders, ['a'])).value;

    await asked<FolderChanged>(
      folders,
      (ticket) => ChangeFolder(ticket, a.copyWith(name: 'Work', color: 'pink')),
    );

    plugin = FakePlugin();
    expect((await settledFolders(owner())).single.name, 'Work');
  });

  test('removing secures open files first, then forgets the folder and '
      'its drafts', () async {
    final folders = owner();
    final [a, _] = (await add(folders, ['a', 'b'])).value;

    await asked<FolderRemoved>(folders, (ticket) => RemoveFolder(ticket, a));

    expect(calls, ['secure fake-a close', 'forget fake-a']);
    expect(plugin.folders.map((folder) => folder.id), ['b']);
    plugin = FakePlugin();
    expect((await settledFolders(owner())).map((f) => f.id), [folderId('b')]);
  });

  test('counts the drafts removing would delete, once its open files are '
      'secured', () async {
    final folders = owner();
    final [a] = (await add(folders, ['a'])).value;
    drafts[a.id] = 2;

    final counted = await asked<DraftsCounted>(
      folders,
      (ticket) => CountDrafts(ticket, a),
    );

    expect(counted.count, 2);
    expect(calls, ['secure fake-a hide', 'count fake-a']);
  });

  test('a list and plugin state that disagree are unreadable, and no '
      'plugin holds a folder', () async {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '{"folders": [{"plugin": "fake", "id": "a", "name": "A", '
        '"color": "teal"}], "plugins": {"fake": ["a", "b"]}}',
      );

    final folders = owner();

    expect(await settledList(folders), isA<FoldersUnreadable>());
    expect(plugin.folders, isEmpty);
  });

  test('never saves over a list it could not load', () async {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync('not json');
    final folders = owner();

    expect((await add(folders, ['a'])).error, FolderError.notSaved);
    expect(file.readAsStringSync(), 'not json');
  });
}

/// [_inner], whose saves fail.
final class _FailingSave implements FolderListStore {
  _FailingSave(this._inner);

  final FolderListStore _inner;

  @override
  Future<Result<SavedFolders, SettingsError>> load() => _inner.load();

  @override
  Future<Result<void, SettingsError>> save(SavedFolders saved) async =>
      const Err(SettingsError.unwritable);
}
