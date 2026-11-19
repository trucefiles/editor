import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/files/file_actions.dart';
import 'package:truce_editor/files/files_wiring.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/open_folders_wiring.dart';
import 'package:truce_editor/images/image_cleanup.dart';
import 'package:truce_editor/images/images_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';

/// Document images on real folders: kept apart from the documents,
/// copied along and relinked as documents move, brought back as they
/// come back.
void main() {
  late ProviderContainer container;
  late FileActions actions;
  late Directory work;
  late Directory home;
  late List<Folder> folders;

  const name = 'img-0123456789abcdef.png';
  const kept = 'document-images/$name';

  setUp(() async {
    work = tempFolder();
    home = tempFolder();
    folders = [folderAt(work, id: 'work'), folderAt(home, id: 'home')];
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        loadedDeviceSettingsProvider.overrideWithValue(DeviceSettings.standard),
      ],
    );
    addTearDown(container.dispose);
    await saveFolders(container, folders);
    actions = container.read(fileActionsProvider);
    File('${work.path}/$kept').writeCreatingFolders('png');
  });

  File diskFile(Directory dir, String name) => File('${dir.path}/$name');

  Future<FolderFiles> scans() async {
    await container.read(folderContentsProvider.future);
    return (await container.read(folderContentsProvider.notifier).refresh())!
        .shown;
  }

  Future<FileText> fileIn(Directory dir, String name, String text) async {
    diskFile(dir, name).writeCreatingFolders(text);
    final listed = (await scans()).files.singleWhere(
      (each) => each.path.value == name,
    );
    return (await container
            .read(fileAccessProvider)
            .of(listed.folder)
            .reload(listed))
        .value;
  }

  test('images never show among the files', () async {
    await fileIn(work, 'plan.md', 'a');
    diskFile(work, 'document-images/notes.md').writeAsStringSync('hidden');

    final shown = (await scans()).files.map((file) => file.path.value);

    expect(shown, ['plan.md']);
  });

  test('a move deeper changes the links of ours in one write', () async {
    final file = await fileIn(
      work,
      'plan.md',
      '# Plan\n\n![a]($kept)\n\n![b](pics/x.png)\n',
    );

    final moved = (await actions.move(file, (
      folder: folders[0],
      subfolder: path('a/b'),
    ), newSubfolder: true)).value;

    const text = '# Plan\n\n![a](../../$kept)\n\n![b](pics/x.png)\n';
    expect(diskFile(work, 'a/b/plan.md').readAsStringSync(), text);
    expect(moved.text, text);
  });

  test('a move at the same depth keeps the file byte for byte', () async {
    final file = await fileIn(work, 'a/plan.md', '![a](../$kept)\r\n');

    await actions.move(file, (
      folder: folders[0],
      subfolder: path('b'),
    ), newSubfolder: true);

    expect(
      diskFile(work, 'b/plan.md').readAsStringSync(),
      '![a](../$kept)\r\n',
    );
  });

  test('a link to an image not kept is never touched', () async {
    const other = 'document-images/img-fedcba9876543210.png';
    final file = await fileIn(work, 'plan.md', '![a]($other)\n');

    await actions.move(file, (
      folder: folders[0],
      subfolder: path('a'),
    ), newSubfolder: true);

    expect(diskFile(work, 'a/plan.md').readAsStringSync(), '![a]($other)\n');
  });

  test('a move to another folder copies the images first', () async {
    final file = await fileIn(work, 'plan.md', '![a]($kept)\n');

    await actions.move(file, (folder: folders[1], subfolder: null));

    expect(diskFile(home, kept).readAsStringSync(), 'png');
    expect(diskFile(work, kept).existsSync(), isTrue, reason: 'still kept');
    expect(diskFile(home, 'plan.md').readAsStringSync(), '![a]($kept)\n');
  });

  test('an undone delete brings back an image removed meanwhile', () async {
    final file = await fileIn(work, 'plan.md', '![a]($kept)\n');
    final deleted = (await actions.delete(file, '![a]($kept)\n')).value;
    final store = container.read(documentImageStoresProvider)(folders[0].id);
    await store.remove((await store.images()).value[name]!);
    expect(diskFile(work, kept).existsSync(), isFalse);

    await actions.undoDelete(deleted);

    expect(diskFile(work, kept).readAsStringSync(), 'png');
  });

  test('an image added once the folder is gone never makes it again', () async {
    await scans();
    work.deleteSync(recursive: true);
    // For the temp folder's own cleanup.
    addTearDown(work.createSync);
    final store = container.read(documentImageStoresProvider)(folders[0].id);

    final added = await store.add(
      bytesOf('png'),
      extension: 'png',
      documentFolder: null,
    );

    expect(added, isA<Err<String, StoreError>>());
    expect(work.existsSync(), isFalse);
  });

  test('a restore as new at another level changes the links too', () async {
    final file = await fileIn(work, 'a/plan.md', '![a](../$kept)\n');
    await actions.delete(file, '![a](../$kept)\n');
    final backups = container
        .read(folderServicesProvider(folders[0].id))
        .backups;
    final backup = (
      folder: folders[0],
      backup: (await backups.listOf(file.path)).value.single,
    );

    await actions.restoreAsNew(backup, (folder: folders[1], subfolder: null));

    expect(diskFile(home, 'plan.md').readAsStringSync(), '![a]($kept)\n');
    expect(diskFile(home, kept).readAsStringSync(), 'png');
  });

  /// The cleanup as it runs [later] from now.
  ImageCleanup cleanupIn(Duration later) => ImageCleanup(
    servicesOf: container.read(openFoldersProvider).servicesOf,
    draftsOf: container.read(draftsProvider).of,
    openFiles: container.read(openFilesProvider),
    now: () => DateTime.now().add(later),
  );

  test('cleanup finds only images no document shows', () async {
    const unused = 'document-images/img-fedcba9876543210.png';
    diskFile(work, unused).writeAsStringSync('old');
    await fileIn(work, 'plan.md', '![a]($kept)\n');

    final found = (await cleanupIn(
      const Duration(hours: 2),
    ).find(folders[0].id)).value;

    expect(found.map((image) => image.path.value), [unused]);
  });

  test('cleanup leaves an image that just came here, however old', () async {
    const synced = 'document-images/img-fedcba9876543210.png';
    diskFile(work, synced).writeAsStringSync('from the phone');
    // As a sync tool puts it: the time it had on the other device.
    diskFile(
      work,
      synced,
    ).setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));

    final found =
        (await container.read(imageCleanupProvider).find(folders[0].id)).value;

    expect(found, isEmpty);
  });
}
