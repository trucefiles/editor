import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/open_folders_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';

void main() {
  test(
    'a provider that is the first to hear of a list change builds',
    () async {
      final container = ProviderContainer(
        overrides: [
          appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
          deviceIdProvider.overrideWithValue('0123456789abcdef'),
          loadedDeviceSettingsProvider.overrideWithValue(
            DeviceSettings.standard,
          ),
        ],
      );
      addTearDown(container.dispose);
      final folder = await addSyncthingFolder(container, tempFolder());
      // Builds the first time it is read: in a listener of the folder list
      // owner that runs before the open folders' own.
      final probe = Provider.family<FolderServices, FolderId>(
        (ref, folder) => ref.watch(openFoldersProvider).servicesOf(folder),
      );
      final errors = <Object>[];
      final owner = container.read(folderListOwnerProvider);
      final early = owner.changes.listen((_) {
        try {
          container.read(probe(folder.id));
        } on Object catch (error) {
          errors.add(error);
        }
      });
      addTearDown(early.cancel);
      container.listen(folderServicesProvider(folder.id), (_, _) {});

      await container.read(foldersProvider.notifier).remove(folder);
      await pumpEventQueue();

      expect(errors, isEmpty);
    },
  );
}
