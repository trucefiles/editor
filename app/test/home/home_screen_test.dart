import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_editor/app.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/sync_tool/sync_tools_wiring.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';

/// Waits until [finder] finds a widget, for files read in real time;
/// fails after a few seconds.
Future<void> showsSoon(WidgetTester tester, Finder finder) async {
  final until = DateTime.now().add(const Duration(seconds: 10));
  while (finder.evaluate().isEmpty) {
    expect(DateTime.now().isBefore(until), isTrue, reason: '$finder');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  setUpAll(initializeDateFormatting);

  /// Starts the app on a folder holding [files].
  Future<void> start(WidgetTester tester, Map<String, String> files) async {
    final dir = tempFolder();
    for (final MapEntry(key: name, value: text) in files.entries) {
      File('${dir.path}/$name').writeCreatingFolders(text);
    }
    final storage = AppStorage(tempFolder().path);
    final scope = ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        loadedDeviceSettingsProvider.overrideWithValue(DeviceSettings.standard),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        systemTrayProvider.overrideWithValue(null),
        hostPathsProvider.overrideWithValue(const SameHostPaths()),
        syncToolsProvider.overrideWith((ref) => SyncTools([hostSyncthing()])),
      ],
      child: const TruceApp(),
    );
    await tester.runAsync(() async {
      final container = ProviderContainer(overrides: scope.overrides);
      await container.read(folderListStoreProvider).save([folderAt(dir)]);
      container.dispose();
      await tester.pumpWidget(scope);
    });
    await showsSoon(tester, find.text('Notes'));
  }

  testWidgets('no Calendar tab while the folders hold no calendar', (
    tester,
  ) async {
    await start(tester, {'notes.md': '# Notes'});

    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a Calendar tab once the folders hold a calendar', (
    tester,
  ) async {
    await start(tester, {
      'notes.md': '# Notes',
      'home.ics': newCalendarText('Home'),
    });

    await tester.tap(find.text('Calendar'));
    await showsSoon(tester, find.widgetWithText(FilterChip, 'Home'));
  });
}
