import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/backups/all_backups.dart';
import 'package:truce_editor/document_page/open_documents.dart';
import 'package:truce_editor/documents/document_draft.dart';
import 'package:truce_editor/documents/document_drafts.dart';
import 'package:truce_editor/documents/document_steps.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folder_error.dart';
import 'package:truce_editor/folders/folder_list_contract.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/host_paths.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

import '../support.dart';

void main() {
  late AppStorage storage;

  setUp(() => storage = AppStorage(tempFolder().path));

  ProviderContainer container({HostPaths hostPaths = const SameHostPaths()}) {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        hostPathsProvider.overrideWithValue(hostPaths),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Result<DocumentFolder, FolderError>> add(
    ProviderContainer folders,
    String basePath, {
    Selection selection = const WholeFolder(),
    String name = 'Documents',
  }) => folders
      .read(foldersProvider.notifier)
      .add(
        address: basePath.contains('://')
            ? Uri.parse(basePath)
            : Uri.file(basePath),
        toolId: 'syncthing',
        selection: selection,
        name: name,
        color: const Color(0xFF009688),
      );

  Selection subfolders(List<String> paths) =>
      Selection.of([for (final value in paths) path(value)]);

  test('adds a folder, saved for the next start', () async {
    final folders = container();

    final added = (await add(
      folders,
      '/sync',
      selection: subfolders(['work']),
    )).value;

    expect(added.base.address, Uri.file('/sync'));
    expect(added.base.toolId, 'syncthing');
    expect(added.selection, subfolders(['work']));
    expect(await container().read(foldersProvider.future), [added]);
  });

  test('folders of one base folder share it', () async {
    final folders = container();

    final work = (await add(
      folders,
      '/sync',
      selection: subfolders(['work']),
    )).value;
    final home = (await add(
      folders,
      '/sync',
      selection: subfolders(['home']),
    )).value;

    expect(home.base, work.base);
    expect(home.id, isNot(work.id));
  });

  test('refuses parts another folder shows', () async {
    final folders = container();
    await add(folders, '/sync', selection: subfolders(['work']));

    expect(
      (await add(folders, '/sync', selection: subfolders(['work/2026']))).error,
      FolderError.overlaps,
    );
    expect((await add(folders, '/sync')).error, FolderError.overlaps);
    expect(
      await add(folders, '/sync', selection: subfolders(['workshop'])),
      isA<Ok<DocumentFolder, FolderError>>(),
    );
  });

  test('refuses a base folder inside or holding an added one', () async {
    final folders = container();
    await add(folders, '/sync/Documents');

    expect(
      (await add(folders, '/sync/Documents/work/2026')).error,
      FolderError.overlaps,
    );
    expect((await add(folders, '/sync')).error, FolderError.overlaps);
    expect(
      await add(folders, '/sync/Documents2'),
      isA<Ok<DocumentFolder, FolderError>>(),
    );
  });

  test('base folders of other kinds of place never overlap', () async {
    final folders = container();
    await add(folders, '/sync');

    expect(
      await add(folders, 'fake://host/sync/Documents'),
      isA<Ok<DocumentFolder, FolderError>>(),
    );
    expect(
      (await add(folders, 'fake://host/sync')).error,
      FolderError.overlaps,
    );
  });

  test("refuses the sync tool's own folders, also on the host", () async {
    final folders = container(
      hostPaths: const _FakeHostPaths({
        '/doc/1/Documents': '/sync/.stversions/Documents',
      }),
    );

    expect(
      (await add(folders, '/sync/.stversions')).error,
      FolderError.syncToolInternal,
    );
    expect(
      (await add(folders, '/doc/1/Documents')).error,
      FolderError.syncToolInternal,
    );
    expect(await folders.read(foldersProvider.future), isEmpty);
  });

  test('tells base folders apart by their host paths', () async {
    final folders = container(
      hostPaths: const _FakeHostPaths({
        '/doc/1/Documents': '/sync/Documents',
        '/doc/2/work': '/sync/Documents/work',
        '/doc/3/Documents': '/sync/Documents',
      }),
    );
    final first = (await add(
      folders,
      '/doc/1/Documents',
      selection: subfolders(['a']),
    )).value;

    expect((await add(folders, '/doc/2/work')).error, FolderError.overlaps);
    final again = (await add(
      folders,
      '/doc/3/Documents',
      selection: subfolders(['b']),
    )).value;
    expect(again.base, first.base);
  });

  test('saves changes and removals for the next start', () async {
    final first = container();
    final a = (await add(first, '/sync/a')).value;
    final b = (await add(first, '/sync/b')).value;
    final controller = first.read(foldersProvider.notifier);

    await controller.change(a.copyWith(name: 'Work'));
    await controller.remove(b);

    final loaded = await container().read(foldersProvider.future);
    expect(loaded.map((f) => (f.id, f.name)), [(a.id, 'Work')]);
  });

  test('refuses a change to parts another folder shows', () async {
    final folders = container();
    final work = (await add(
      folders,
      '/sync',
      selection: subfolders(['work']),
    )).value;
    await add(folders, '/sync', selection: subfolders(['home']));

    final changed = await folders
        .read(foldersProvider.notifier)
        .change(work.copyWith(selection: subfolders(['home/notes'])));

    expect(changed.error, FolderError.overlaps);
    expect((await folders.read(foldersProvider.future)).first, work);
  });

  test('changes made at the same time all land', () async {
    final first = container();
    final a = (await add(first, '/sync/a', name: 'a')).value;
    final b = (await add(first, '/sync/b', name: 'b')).value;
    final controller = first.read(foldersProvider.notifier);

    await Future.wait([
      controller.remove(a),
      controller.change(b.copyWith(name: 'Work')),
      add(first, '/sync/c', name: 'c'),
    ]);

    final loaded = await container().read(foldersProvider.future);
    expect(loaded.map((f) => f.name), ['Work', 'c']);
  });

  test('keeps the open documents of a base folder before what it shows '
      'changes', () async {
    final folders = container();
    final work = (await add(
      folders,
      '/sync',
      selection: subfolders(['work']),
    )).value;
    final secured = <String>[];
    folders
        .read(openDocumentsProvider)
        .add(
          base: () => work.base,
          secure: () async {
            secured.add(
              (await folders.read(foldersProvider.future)).single.selection
                  .toString(),
            );
          },
        );
    final controller = folders.read(foldersProvider.notifier);

    await controller.change(work.copyWith(name: 'Work'));
    expect(secured, isEmpty);

    await controller.change(work.copyWith(selection: subfolders(['other'])));
    expect(secured, [
      subfolders(['work']).toString(),
    ]);

    await controller.remove(work.copyWith(selection: subfolders(['other'])));
    expect(secured, hasLength(2));
  });

  group('removing a folder', () {
    DocumentDraft draft(String id, String at) =>
        DocumentDraft(id: id, path: path(at), base: '', text: 'mine');

    Future<List<String>> draftsOf(
      ProviderContainer folders,
      String baseId,
    ) async => [
      for (final kept
          in await folders
              .read(documentDraftsProvider(baseId))
              .all(before: DateTime.now().add(const Duration(days: 1))))
        kept.id,
    ];

    test('deletes the drafts it showed, not those of other folders', () async {
      final folders = container();
      final work = (await add(
        folders,
        '/sync',
        selection: subfolders(['work']),
      )).value;
      await add(folders, '/sync', selection: subfolders(['home']));
      final drafts = folders.read(documentDraftsProvider(work.base.id));
      await drafts.keep(draft('1', 'work/a.md'));
      await drafts.keep(draft('2', 'home/a.md'));
      await drafts.keep(draft('3', 'elsewhere/a.md'));

      await folders.read(foldersProvider.notifier).remove(work);

      expect(
        await draftsOf(folders, work.base.id),
        unorderedEquals(['2', '3']),
      );
    });

    test("with its base folder's last folder, all of its drafts go", () async {
      final folders = container();
      final work = (await add(
        folders,
        '/sync',
        selection: subfolders(['work']),
      )).value;
      final drafts = folders.read(documentDraftsProvider(work.base.id));
      await drafts.keep(draft('1', 'work/a.md'));
      await drafts.keep(draft('2', 'elsewhere/a.md'));

      await folders.read(foldersProvider.notifier).remove(work);

      expect(await draftsOf(folders, work.base.id), isEmpty);
    });
  });

  test('never saves over a list it could not load', () async {
    final file = File('${storage.settingsPath}/folder_list.json');
    file.writeCreatingFolders('{"broken": true}');
    final folders = container();
    await folders
        .read(folderListOwnerProvider)
        .changes
        .firstWhere((list) => list is! FoldersLoading);
    expect(folders.read(folderListStateProvider), isA<FoldersUnreadable>());
    expect(folders.read(foldersProvider).isLoading, isTrue);

    expect((await add(folders, '/sync')).error, FolderError.notSaved);
    expect(file.readAsStringSync(), '{"broken": true}');
  });

  test('a list it could not load leaves nothing to act on, and nothing '
      'waits on it', () async {
    File('${storage.settingsPath}/folder_list.json')
        .writeCreatingFolders('{"broken": true}');
    final folders = container();

    await folders
        .read(documentStepsProvider)
        .recoverDrafts(before: DateTime.now());
    expect(await folders.read(allBackupsProvider.future), isEmpty);
  });
}

/// Host paths from a table; other paths are their own.
final class _FakeHostPaths implements HostPaths {
  const _FakeHostPaths(this._hostPaths);

  final Map<String, String> _hostPaths;

  @override
  Future<Uri> of(Uri address) async =>
      switch (_hostPaths[address.toFilePath()]) {
        final host? => Uri.file(host),
        null => address,
      };
}
