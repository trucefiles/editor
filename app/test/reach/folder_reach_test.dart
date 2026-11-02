import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/files/file_actions.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/reach/folder_reach_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';

/// The whole flow on the real folder services: a folder that goes away is
/// retried, then unreachable while the other stays usable, and reachable
/// again once it is back.
void main() {
  late ProviderContainer container;
  late Directory work;
  late Folder workFolder;
  late Folder homeFolder;

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
    await saveFolders(container, [workFolder, homeFolder]);
    await container.read(folderContentsProvider.future);
  });

  Reach reachOf(Folder folder) =>
      container.read(folderReachProvider(folder.id));

  /// Once [folder]'s reach is [reach].
  Future<void> reached(Folder folder, Reach reach) async {
    final done = Completer<void>();
    final listening = container.listen(folderReachProvider(folder.id), (
      _,
      next,
    ) {
      if (next == reach && !done.isCompleted) done.complete();
    }, fireImmediately: true);
    await done.future;
    listening.close();
  }

  test('a folder that is gone is retried, then unreachable', () async {
    final seen = <Reach>[];
    container.listen(
      folderReachProvider(workFolder.id),
      (_, next) => seen.add(next),
    );
    work.renameSync('${work.path}-away');

    await container.read(folderContentsProvider.notifier).refresh();
    // The check that finds it gone reads the disk: wait for it, however
    // long a busy machine takes.
    await reached(workFolder, Reach.retrying);
    expect(container.read(retryingFoldersProvider), [workFolder]);

    expect(
      await container
          .read(folderReachProvider(workFolder.id).notifier)
          .settled(),
      Reach.unreachable,
    );
    expect(reachOf(workFolder), Reach.unreachable);
    expect(reachOf(homeFolder), Reach.reachable);
    expect(container.read(retryingFoldersProvider), isEmpty);
    expect(
      container.read(fileActionsProvider).reachableOf([workFolder, homeFolder]),
      [homeFolder],
    );

    Directory('${work.path}-away').renameSync(work.path);
    await container.read(folderContentsProvider.notifier).refresh();

    expect(reachOf(workFolder), Reach.reachable);
    expect(seen, [Reach.retrying, Reach.unreachable, Reach.reachable]);
  });

  test('a deleted document changes nothing', () async {
    final file =
        (await container
                .read(fileActionsProvider)
                .create(
                  (folder: workFolder, subfolder: null),
                  type: appFileTypes().forNew,
                  title: 'b',
                  text: '# b\n',
                ))
            .value;
    File('${work.path}/${file.path.value}').deleteSync();

    await container.read(folderContentsProvider.notifier).refresh();
    await pumpEventQueue();

    expect(reachOf(workFolder), Reach.reachable);
  });
}
