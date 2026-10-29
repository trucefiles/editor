import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/home/home_settings.dart';
import 'package:truce_editor/editor/add_item_place/add_item_place.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_target.dart';

import '../support.dart';

void main() {
  /// Every setting changed from the standard.
  final changed = DeviceSettings(
    documentTextZoom: TextZoom.closestTo(130),
    appTextZoom: TextZoom.closestTo(150),
    newFilePlace: (folderId: 'f1', subfolder: path('inbox')),
    refresh: const RefreshSettings(
      mode: RefreshMode.manual,
      interval: Duration(seconds: 30),
    ),
    addItemPlace: AddItemPlace.bottom,
    closeToTray: false,
    home: const HomeSettings(
      recentCount: 100,
      order: DocumentOrder.name,
      view: DocumentView.list,
    ),
  );

  group('value', () {
    test('reads back what it writes', () {
      expect(DeviceSettings.fromJson(changed.toJson()), changed);
      expect(
        DeviceSettings.fromJson(DeviceSettings.standard.toJson()),
        DeviceSettings.standard,
      );
    });

    test('a missing or broken setting takes its standard, the others '
        'stay', () {
      final json = changed.toJson()
        ..remove('appTextZoom')
        ..['refresh'] = 'often';

      expect(
        DeviceSettings.fromJson(json),
        changed.copyWith(
          appTextZoom: TextZoom.normal,
          refresh: RefreshSettings.standard,
        ),
      );
    });

    test('is the standard for JSON that holds no settings', () {
      expect(DeviceSettings.fromJson('settings'), DeviceSettings.standard);
      expect(DeviceSettings.fromJson(null), DeviceSettings.standard);
    });

    test('sets each text zoom on its own', () {
      final settings = DeviceSettings.standard.withTextZoom(
        TextZoomTarget.app,
        TextZoom.closestTo(120),
      );

      expect(settings.textZoomOf(TextZoomTarget.app), TextZoom.closestTo(120));
      expect(settings.textZoomOf(TextZoomTarget.documents), TextZoom.normal);
    });

    test('copies keep the place for new documents, and can clear it', () {
      expect(changed.copyWith(closeToTray: true).newFilePlace, isNotNull);
      expect(changed.copyWith(newFilePlace: () => null).newFilePlace, isNull);
    });
  });

  group('store', () {
    late AppStorage storage;

    setUp(() => storage = AppStorage(tempFolder().path));

    test('is the standard until something is saved', () async {
      expect(
        await deviceSettingsStoreIn(storage).load(),
        DeviceSettings.standard,
      );
    });

    test('keeps the settings in one file', () async {
      await deviceSettingsStoreIn(storage).save(changed);

      expect(await deviceSettingsStoreIn(storage).load(), changed);
      expect(Directory(storage.settingsPath).listSync(), hasLength(1));
    });

    test('is the standard for an unreadable file', () async {
      File('${storage.settingsPath}/device_settings.json')
          .writeCreatingFolders('{not json');

      expect(
        await deviceSettingsStoreIn(storage).load(),
        DeviceSettings.standard,
      );
    });
  });

  group('controller', () {
    late AppStorage storage;

    setUp(() => storage = AppStorage(tempFolder().path));

    /// The app as `main` starts it on [storage]: the settings loaded first.
    Future<ProviderContainer> start() async {
      final container = ProviderContainer(
        overrides: [
          appStorageProvider.overrideWithValue(storage),
          loadedDeviceSettingsProvider.overrideWithValue(
            await deviceSettingsStoreIn(storage).load(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('has the settings from the start, never still loading', () async {
      final app = await start();

      expect(
        app.read(deviceSettingsProvider),
        const AsyncData(DeviceSettings.standard),
      );
    });

    test('a change shows at once, and is there at the next start', () async {
      final first = await start();

      final saving = first
          .read(deviceSettingsProvider.notifier)
          .change((settings) => settings.copyWith(closeToTray: false));
      expect(
        first.read(deviceSettingsProvider).requireValue.closeToTray,
        false,
      );
      await saving;

      final next = await start();
      expect(next.read(deviceSettingsProvider).requireValue.closeToTray, false);
    });

    test('changes made at once each start from the one before', () async {
      final first = await start();
      final settings = first.read(deviceSettingsProvider.notifier);

      await Future.wait([
        settings.change(
          (s) =>
              s.withTextZoom(TextZoomTarget.documents, TextZoom.normal.larger),
        ),
        settings.change((s) => s.copyWith(addItemPlace: AddItemPlace.bottom)),
      ]);

      final next = await start();
      final saved = next.read(deviceSettingsProvider).requireValue;
      expect(saved.documentTextZoom, TextZoom.closestTo(110));
      expect(saved.addItemPlace, AddItemPlace.bottom);
    });
  });
}
