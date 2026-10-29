import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/document_actions.dart';
import 'package:truce_editor/documents/document_files.dart';
import 'package:truce_editor/documents/move_failure.dart';
import 'package:truce_editor/documents/open_failure.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folder_state/following_changes.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/app_activity.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_editor/sync_tool/sync_tools.dart';
import 'package:truce_test_support/truce_test_support.dart'
    show FakePlace, FakeSyncTool;

import '../support.dart';

/// The app's generic code works unchanged for a sync tool with no files on
/// disk: a fake one keeps its places in memory, at `fake:` addresses.
void main() {
  final address = Uri.parse('fake://host/docs');
  late FakeSyncTool tool;
  late FakePlace place;
  late ProviderContainer container;
  late DocumentFolder folder;

  setUp(() async {
    tool = FakeSyncTool('fake');
    place = tool.place(address);
    place.files
      ..put('work/a.md', '# A')
      ..put('home/b.md', '# B');
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        loadedDeviceSettingsProvider.overrideWithValue(DeviceSettings.standard),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        syncToolsProvider.overrideWithValue(SyncTools([tool])),
        appActiveProvider.overrideWith(_Active.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(foldersProvider.future);
    folder =
        (await container
                .read(foldersProvider.notifier)
                .add(
                  address: address,
                  toolId: tool.id,
                  selection: Selection.of([path('work')]),
                  name: 'Docs',
                  color: const Color(0xFF009688),
                ))
            .value;
  });

  Future<List<String>> listed() async {
    await container.read(folderContentsProvider.future);
    final contents = (await container
        .read(folderContentsProvider.notifier)
        .refresh())!;
    return [for (final document in contents.documents) document.path.value];
  }

  test('lists, opens, saves, creates and moves documents, into a new '
      'subfolder too', () async {
    final actions = container.read(documentActionsProvider);
    final files = container.read(documentFilesProvider(folder));

    expect(await listed(), ['work/a.md']);
    final a = (await files.open(path('work/a.md'))).value;
    await files.save(a, '# A\nmore');
    final created = (await actions.create(
      (folder: folder, subfolder: path('work')),
      type: appDocumentTypes().forNew,
      title: 'New',
      text: '# New',
    )).value;
    final moved = await actions.move(created, (
      folder: folder,
      subfolder: path('work/inbox'),
    ), newSubfolder: true);

    expect(place.files.textOf('work/a.md'), '# A\nmore');
    expect(moved.value.path, path('work/inbox/New.md'));
    expect(place.files.textOf('work/inbox/New.md'), '# New');
    expect(await listed(), unorderedEquals(['work/a.md', 'work/inbox/New.md']));
    expect(
      (await files.open(path('home/b.md'))).error,
      const NotRead(StoreError.outside),
    );
    expect(
      (await actions.move(moved.value, (
        folder: folder,
        subfolder: path('home/new'),
      ), newSubfolder: true)).error,
      isA<MoveNotWritten>().having(
        (failure) => failure.error,
        'error',
        StoreError.outside,
      ),
    );
    expect(place.files.textOf('work/inbox/New.md'), '# New');
  });

  test('follows the tool\'s live changes of what the folder shows', () async {
    container.listen(followingChangesProvider, (_, _) {});
    await container.read(followingChangesProvider.future);
    await listed();
    await eventually(() => place.changes.follows(path('work')));

    place.files.put('work/c.md', '# C');
    place.changes.hint(path('work'), PathChanged(path('work/c.md')));

    await eventually(
      () async =>
          (container.read(folderContentsProvider).value?.documents ?? []).any(
            (document) => document.path.value == 'work/c.md',
          ),
    );
    expect(place.changes.followed, [path('work')]);
  });
}

class _Active extends AppActivity {
  @override
  bool build() => true;
}
