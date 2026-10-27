import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_settings_controller.dart';
import 'package:truce_editor/documents/document_settings_pruning.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/app_activity.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

import '../support.dart';

void main() {
  late ProviderContainer container;
  late Directory dir;

  setUp(() async {
    dir = tempFolder();
    File('${dir.path}/kept.md').writeAsStringSync('# Kept\n');
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        appActiveProvider.overrideWith(_Activity.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(folderSettingsStoreProvider).save([folderAt(dir)]);
  });

  DocumentKey key(String name) => (folderId: 'f1', path: path(name));

  test(
    'marks the settings of gone documents missing as the app comes into use',
    () async {
      final views = container.read(documentSettingsProvider.notifier);
      await views.edit(key('kept.md'), (s) => s.withMode(EditMode.visual));
      await views.edit(key('gone.md'), (s) => s.withMode(EditMode.markdown));
      final activity = container.read(appActiveProvider.notifier) as _Activity
        ..set(active: false);
      container.listen(documentSettingsPruningProvider, (_, _) {});
      await container.read(documentSettingsPruningProvider.future);
      expect(views.settingsOf(key('gone.md')).mode, EditMode.markdown);

      activity.set(active: true);
      await container.read(documentSettingsPruningProvider.future);

      // Forgotten once missing for a while (see the controller's tests).
      final kept = container.read(documentSettingsProvider).value!;
      expect(kept['f1/gone.md']!.missingSince, isNotNull);
      expect(kept['f1/kept.md']!.missingSince, isNull);
      expect(views.settingsOf(key('gone.md')).mode, EditMode.markdown);
    },
  );

  test(
    'keeps the settings of a document written after the last scan',
    () async {
      final activity = container.read(appActiveProvider.notifier) as _Activity
        ..set(active: false);
      container.listen(documentSettingsPruningProvider, (_, _) {});
      await container.read(folderScansProvider.future);
      // E.g. a document just moved here: no scan has seen it yet.
      File('${dir.path}/moved.md').writeAsStringSync('# Moved\n');
      final views = container.read(documentSettingsProvider.notifier);
      await views.edit(key('moved.md'), (s) => s.withPinned(pinned: true));

      activity.set(active: true);
      await container.read(documentSettingsPruningProvider.future);

      expect(views.settingsOf(key('moved.md')).pinned, isTrue);
    },
  );
}

class _Activity extends AppActivity {
  @override
  bool build() => true;

  void set({required bool active}) => state = active;
}
