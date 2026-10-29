import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folder_actions.dart';
import 'package:truce_editor/folders/folder_selection.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/host_paths.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/platform/storage_access.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';

void main() {
  late _FakeAccess access;
  late ProviderContainer container;
  late FolderActions actions;

  setUp(() {
    access = _FakeAccess();
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        storageAccessProvider.overrideWithValue(access),
        hostPathsProvider.overrideWithValue(const SameHostPaths()),
      ],
    );
    addTearDown(container.dispose);
    actions = container.read(folderActionsProvider);
  });

  Future<void> add(String basePath) => container
      .read(foldersProvider.notifier)
      .add(
        address: Uri.file(basePath),
        toolId: 'syncthing',
        selection: const WholeFolder(),
        name: basePath,
        color: const Color(0xFF009688),
      );

  test('asks the platform for access', () async {
    expect(await actions.hasAccess(), isFalse);

    await actions.requestAccess();

    expect(await actions.hasAccess(), isTrue);
  });

  test('remove stops filtering the documents by that folder', () async {
    await add('/sync/a');
    await add('/sync/b');
    final [a, b] = await container.read(foldersProvider.future);
    final selection = container.read(selectedFolderIdProvider.notifier);

    selection.choose(b.id);
    await actions.remove(a);
    expect(container.read(selectedFolderIdProvider), b.id);

    await actions.remove(b);
    expect(container.read(selectedFolderIdProvider), isNull);
    expect(await container.read(foldersProvider.future), isEmpty);
  });

  test('change saves the folder', () async {
    await add('/sync/a');
    final [a] = await container.read(foldersProvider.future);

    await actions.change(a.copyWith(name: 'Work'));

    final [changed] = await container.read(foldersProvider.future);
    expect(changed.name, 'Work');
  });
}

final class _FakeAccess implements StorageAccess {
  bool _granted = false;

  @override
  Future<bool> isGranted() async => _granted;

  @override
  Future<void> request() async => _granted = true;
}
