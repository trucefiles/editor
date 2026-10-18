import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note_actions.dart';
import 'package:truce_editor/reach/folder_reach_controller.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

import '../support.dart';

/// The whole flow on the real folder services: a folder that goes away is
/// retried, then unreachable while the other stays usable, and reachable
/// again once it is back.
void main() {
  late ProviderContainer container;
  late Directory work;
  late NoteFolder workFolder;
  late NoteFolder homeFolder;

  setUp(() async {
    work = tempFolder();
    workFolder = folderAt(work, id: 'work');
    homeFolder = folderAt(tempFolder(), id: 'home');
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(folderSettingsStoreProvider).save([
      workFolder,
      homeFolder,
    ]);
    await container.read(folderScansProvider.future);
  });

  Reach reachOf(NoteFolder folder) =>
      container.read(folderReachProvider(folder.location));

  test('a folder that is gone is retried, then unreachable', () async {
    final seen = <Reach>[];
    container.listen(
      folderReachProvider(workFolder.location),
      (_, next) => seen.add(next),
    );
    work.renameSync('${work.path}-away');

    await container.read(folderScansProvider.notifier).refresh();
    await pumpEventQueue();
    expect(reachOf(workFolder), Reach.retrying);
    expect(container.read(retryingFoldersProvider), [workFolder]);

    await Future<void>.delayed(const Duration(seconds: 6));
    expect(reachOf(workFolder), Reach.unreachable);
    expect(reachOf(homeFolder), Reach.reachable);
    expect(container.read(retryingFoldersProvider), isEmpty);
    expect(
      container.read(noteActionsProvider).reachableOf([workFolder, homeFolder]),
      [homeFolder],
    );

    Directory('${work.path}-away').renameSync(work.path);
    await container.read(folderScansProvider.notifier).refresh();

    expect(reachOf(workFolder), Reach.reachable);
    expect(seen, [Reach.retrying, Reach.unreachable, Reach.reachable]);
  });

  test('a deleted note changes nothing', () async {
    final note =
        (await container
                .read(noteActionsProvider)
                .create(
                  (folder: workFolder, subfolder: null),
                  title: 'b',
                  text: '# b\n',
                ))
            .value;
    File('${work.path}/${note.path.value}').deleteSync();

    await container.read(folderScansProvider.notifier).refresh();
    await pumpEventQueue();

    expect(reachOf(workFolder), Reach.reachable);
  });
}
