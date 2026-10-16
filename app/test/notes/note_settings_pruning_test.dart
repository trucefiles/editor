import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_settings_controller.dart';
import 'package:truce_editor/notes/note_settings_pruning.dart';
import 'package:truce_editor/notes/note_view.dart';
import 'package:truce_editor/platform/app_activity.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

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

  NoteKey key(String name) => (folderId: 'f1', path: path(name));

  test(
    'forgets the settings of gone notes as the app comes into use',
    () async {
      final views = container.read(noteSettingsProvider.notifier);
      await views.edit(key('kept.md'), (s) => s.withView(NoteView.list));
      await views.edit(key('gone.md'), (s) => s.withView(NoteView.text));
      final activity = container.read(appActiveProvider.notifier) as _Activity
        ..set(active: false);
      container.listen(noteSettingsPruningProvider, (_, _) {});
      await container.read(noteSettingsPruningProvider.future);
      expect(views.settingsOf(key('gone.md')).view, NoteView.text);

      activity.set(active: true);
      await container.read(noteSettingsPruningProvider.future);

      expect(views.settingsOf(key('gone.md')).view, isNull);
      expect(views.settingsOf(key('kept.md')).view, NoteView.list);
    },
  );
}

class _Activity extends AppActivity {
  @override
  bool build() => true;

  void set({required bool active}) => state = active;
}
