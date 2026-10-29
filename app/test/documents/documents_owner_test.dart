import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/documents_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';

void main() {
  test('the app can end while the drafts of the last run are recovered, '
      'before the folder list loaded', () async {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        loadedDeviceSettingsProvider.overrideWithValue(DeviceSettings.standard),
      ],
    );
    final recovered = container.read(documentsProvider).draftsRecovered;

    container.dispose();

    // Ends without an error: nothing is left to recover into.
    await recovered;
  });
}
