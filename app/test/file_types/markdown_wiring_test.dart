import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor/file_types/file_types.dart';
import 'package:truce_editor/file_types/markdown_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';

void main() {
  test('a change of the Add item setting reaches Markdown views, and the '
      'file types stay the same', () async {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        loadedDeviceSettingsProvider.overrideWithValue(DeviceSettings.standard),
      ],
    );
    addTearDown(container.dispose);
    final types = container.read(fileTypesProvider);
    final addItems = container.read(markdownServicesProvider).addItems;
    expect(addItems.value, AddItemPlace.top);

    await container
        .read(deviceSettingsProvider.notifier)
        .change(
          (settings) => settings.copyWith(addItemPlace: AddItemPlace.bottom),
        );

    expect(addItems.value, AddItemPlace.bottom);
    expect(container.read(fileTypesProvider), same(types));
  });
}
