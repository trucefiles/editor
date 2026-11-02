import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/files/file_actions.dart';
import 'package:truce_editor/files/files_wiring.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folder_state/folder_state_wiring.dart';
import 'package:truce_editor/platform/app_activity.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/plugins/plugins_wiring.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart'
    show FakeFolder, FakePlugin;

import '../support.dart';

/// The app's generic code works unchanged for a plugin with no files on
/// disk: a fake one keeps its folders in memory.
void main() {
  late FakePlugin plugin;
  late FakeFolder place;
  late ProviderContainer container;
  late Folder folder;

  setUp(() async {
    plugin = FakePlugin();
    place = plugin.folder('docs');
    place.files
      ..put('a.md', '# A')
      ..put('notes/b.md', '# B');
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        loadedDeviceSettingsProvider.overrideWithValue(DeviceSettings.standard),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        folderPluginsProvider.overrideWithValue(FolderPlugins([plugin])),
        appActiveProvider.overrideWith(_Active.new),
      ],
    );
    addTearDown(container.dispose);
    folder = await addFolderOf(container, plugin, FakePlugin.candidate('docs'));
  });

  Future<List<String>> listed() async {
    await container.read(folderContentsProvider.future);
    final contents = (await container
        .read(folderContentsProvider.notifier)
        .refresh())!;
    return [for (final file in contents.files) file.path.value];
  }

  test('lists, opens, saves, creates and moves files, into a new folder '
      'inside too', () async {
    final actions = container.read(fileActionsProvider);
    final files = container.read(fileAccessProvider).of(folder);

    expect(await listed(), unorderedEquals(['a.md', 'notes/b.md']));
    final a = (await files.open(path('a.md'))).value;
    await files.save(a, '# A\nmore');
    final created = (await actions.create(
      (folder: folder, subfolder: null),
      type: appFileTypes().forNew,
      title: 'New',
      text: '# New',
    )).value;
    final moved = await actions.move(created, (
      folder: folder,
      subfolder: path('inbox'),
    ), newSubfolder: true);

    expect(place.files.textOf('a.md'), '# A\nmore');
    expect(moved.value.path, path('inbox/New.md'));
    expect(place.files.textOf('inbox/New.md'), '# New');
    expect(
      await listed(),
      unorderedEquals(['a.md', 'notes/b.md', 'inbox/New.md']),
    );
  });

  test("follows the plugin's live changes of the folder", () async {
    container.listen(followingChangesProvider, (_, _) {});
    container.read(followingChangesProvider);
    await listed();
    await eventually(() => place.changes.follows);

    place.files.put('c.md', '# C');
    place.changes.hint(PathChanged(path('c.md')));

    await eventually(
      () async => (container.read(folderContentsProvider).value?.files ?? [])
          .any((file) => file.path.value == 'c.md'),
    );
    expect(place.changes.followed, 1);
  });
}

class _Active extends AppActivity {
  @override
  bool build() => true;
}
