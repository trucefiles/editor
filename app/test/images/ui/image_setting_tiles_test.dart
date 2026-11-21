import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/images/ui/image_setting_tiles.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../../support.dart';

void main() {
  testWidgets('removing location says it also drops HDR and motion video', (
    tester,
  ) async {
    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
            loadedDeviceSettingsProvider.overrideWithValue(
              DeviceSettings.standard,
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ImageSettingTiles())),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.widgetWithText(SwitchListTile, 'Also drops HDR and motion video'),
      findsOne,
    );
  });
}
