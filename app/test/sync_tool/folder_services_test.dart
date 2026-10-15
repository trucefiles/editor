import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_editor/sync_tool/folder_services.dart';

import '../support.dart';

void main() {
  test('renaming or recoloring a folder keeps its services', () {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    final folder = folderAt(tempFolder());
    final restyled = folder.copyWith(
      name: 'Other',
      color: const Color(0xFF000000),
    );

    expect(
      container.read(folderServicesProvider(restyled.location)),
      same(container.read(folderServicesProvider(folder.location))),
    );
  });
}
