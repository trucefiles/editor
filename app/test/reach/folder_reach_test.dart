import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/document_actions.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/reach/folder_reach_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

import '../support.dart';

/// The whole flow on the real folder services: a folder that goes away is
/// retried, then unreachable while the other stays usable, and reachable
/// again once it is back.
void main() {
  late ProviderContainer container;
  late Directory work;
  late DocumentFolder workFolder;
  late DocumentFolder homeFolder;

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
    await container.read(folderListStoreProvider).save([
      workFolder,
      homeFolder,
    ]);
    await container.read(folderContentsProvider.future);
  });

  Reach reachOf(DocumentFolder folder) =>
      container.read(folderReachProvider(folder.base));

  test('a folder that is gone is retried, then unreachable', () async {
    final seen = <Reach>[];
    container.listen(
      folderReachProvider(workFolder.base),
      (_, next) => seen.add(next),
    );
    work.renameSync('${work.path}-away');

    await container.read(folderContentsProvider.notifier).refresh();
    await pumpEventQueue();
    expect(reachOf(workFolder), Reach.retrying);
    expect(container.read(retryingFoldersProvider), [workFolder]);

    await Future<void>.delayed(const Duration(seconds: 6));
    expect(reachOf(workFolder), Reach.unreachable);
    expect(reachOf(homeFolder), Reach.reachable);
    expect(container.read(retryingFoldersProvider), isEmpty);
    expect(
      container.read(documentActionsProvider).reachableOf([
        workFolder,
        homeFolder,
      ]),
      [homeFolder],
    );

    Directory('${work.path}-away').renameSync(work.path);
    await container.read(folderContentsProvider.notifier).refresh();

    expect(reachOf(workFolder), Reach.reachable);
    expect(seen, [Reach.retrying, Reach.unreachable, Reach.reachable]);
  });

  test('a deleted document changes nothing', () async {
    final document =
        (await container
                .read(documentActionsProvider)
                .create(
                  (folder: workFolder, subfolder: null),
                  type: appDocumentTypes().forNew,
                  title: 'b',
                  text: '# b\n',
                ))
            .value;
    File('${work.path}/${document.path.value}').deleteSync();

    await container.read(folderContentsProvider.notifier).refresh();
    await pumpEventQueue();

    expect(reachOf(workFolder), Reach.reachable);
  });
}
