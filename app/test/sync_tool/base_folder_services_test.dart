import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/host_paths.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/sync_tool/base_folder_services.dart';

import '../support.dart';

void main() {
  test('renaming or recoloring a folder keeps its services', () {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    final folder = folderAt(tempFolder());
    final restyled = folder.copyWith(
      name: 'Other',
      color: 'teal',
    );

    expect(
      container.read(baseFolderServicesProvider(restyled.base)),
      same(container.read(baseFolderServicesProvider(folder.base))),
    );
  });

  test('a change to what its folders show builds its services again, over '
      'the same reach', () async {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        hostPathsProvider.overrideWithValue(const SameHostPaths()),
      ],
    );
    addTearDown(container.dispose);
    final dir = tempFolder();
    File('${dir.path}/work/a.md').writeCreatingFolders('a');
    File('${dir.path}/home/b.md').writeCreatingFolders('b');
    final folder = folderAt(dir, selection: Selection.of([path('work')]));
    await container.read(folderListStoreProvider).save([folder]);
    await container.read(foldersProvider.future);
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
