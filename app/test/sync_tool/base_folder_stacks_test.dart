import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/host_paths.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/sync_tool/base_folder_wiring.dart';

import '../support.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        hostPathsProvider.overrideWithValue(const SameHostPaths()),
      ],
    );
    addTearDown(container.dispose);
  });

  /// [folders] saved as the folder list, loaded.
  Future<void> listed(List<DocumentFolder> folders) async {
    await container.read(folderListStoreProvider).save(folders);
    await container.read(foldersProvider.future);
  }

  test('renaming or recoloring a folder keeps its services', () async {
    final folder = folderAt(tempFolder());
    await listed([folder]);
    final before = container.read(baseFolderServicesProvider(folder.base));

    await container
        .read(foldersProvider.notifier)
        .change(folder.copyWith(name: 'Other', color: 'pink'));

    expect(
      container.read(baseFolderServicesProvider(folder.base)),
      same(before),
    );
  });

  test('a base folder goes with its last folder: its services touch '
      'nothing and its reach ends', () async {
    final dir = tempFolder();
    File('${dir.path}/a.md').writeCreatingFolders('a');
    final folder = folderAt(dir);
    await listed([folder]);
    final before = container.read(baseFolderServicesProvider(folder.base));

    await container.read(foldersProvider.notifier).remove(folder);
    final after = container.read(baseFolderServicesProvider(folder.base));

    expect((await after.store.read(path('a.md'))).error, StoreError.outside);
    await expectLater(before.reach.changes, emitsDone);
  });

  test('a base folder no folder showed touches nothing', () async {
    final dir = tempFolder();
    File('${dir.path}/a.md').writeCreatingFolders('a');
    await listed([]);

    final services = container.read(
      baseFolderServicesProvider(folderAt(dir).base),
    );

    expect((await services.store.read(path('a.md'))).error, StoreError.outside);
  });

  test('a change to what its folders show builds its services again, over '
      'the same reach', () async {
    final dir = tempFolder();
    File('${dir.path}/work/a.md').writeCreatingFolders('a');
    File('${dir.path}/home/b.md').writeCreatingFolders('b');
    final folder = folderAt(dir, selection: Selection.of([path('work')]));
    await listed([folder]);
    container.listen(baseFolderServicesProvider(folder.base), (_, _) {});
    final before = container.read(baseFolderServicesProvider(folder.base));

    expect(
      (await before.store.read(path('home/b.md'))).error,
      StoreError.outside,
    );

    await container
        .read(foldersProvider.notifier)
        .change(folder.copyWith(selection: Selection.of([path('home')])));
    final after = container.read(baseFolderServicesProvider(folder.base));

    expect(after, isNot(same(before)));
    expect(after.reach, same(before.reach));
    expect(
      await after.store.read(path('home/b.md')),
      isA<Ok<FileContent, StoreError>>(),
    );
    expect(
      (await after.store.read(path('work/a.md'))).error,
      StoreError.outside,
    );
  });
}
