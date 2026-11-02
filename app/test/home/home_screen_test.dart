import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_editor/app.dart';
import 'package:truce_editor/file_page/ui/file_screen.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/home/home_screen.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

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

  /// Starts the app on a folder holding [files]; the folder.
  Future<Directory> start(
    WidgetTester tester,
    Map<String, String> files,
  ) async {
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
      ],
      child: const TruceApp(),
    );
    await tester.runAsync(() async {
      final container = ProviderContainer(overrides: scope.overrides);
      await saveFolders(container, [folderAt(dir)]);
      container.dispose();
      await tester.pumpWidget(scope);
    });
    await showsSoon(tester, find.text('Notes'));
    return dir;
  }

  testWidgets('a type chip shows only files of its type, and all again '
      'when tapped twice', (tester) async {
    await start(tester, {'notes.md': '# Notes', 'list.txt': 'List\nmilk'});
    final textChip = find.widgetWithText(ChoiceChip, 'Plain text');

    await tester.tap(textChip);
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsNothing);
    expect(find.text('List'), findsOneWidget);

    await tester.tap(textChip);
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
  });

  testWidgets('the type chips stay in sight on a narrow screen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await start(tester, {'notes.md': '# Notes'});

    for (final name in ['Markdown', 'Plain text']) {
      final chip = tester.getRect(find.widgetWithText(ChoiceChip, name));
      expect(chip.right, lessThanOrEqualTo(360), reason: name);
    }
  });

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

    await tester.tap(find.widgetWithText(NavigationDestination, 'Calendar'));
    await showsSoon(tester, find.widgetWithText(FilterChip, 'Home'));
  });

  testWidgets('a document opens beside the Calendar tab', (tester) async {
    await start(tester, {
      'notes.md': '# Notes',
      'home.ics': newCalendarText('Home'),
    });

    await tester.tap(find.text('Notes').first);
    await showsSoon(tester, find.byType(FileScreen));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a calendar back after the last went shows the documents', (
    tester,
  ) async {
    final dir = await start(tester, {
      'notes.md': '# Notes',
      'home.ics': newCalendarText('Home'),
    });
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    Future<void> rescan() async {
      await tester.runAsync(
        () => container.read(folderContentsProvider.notifier).refresh(),
      );
      await tester.pump();
    }

    await tester.tap(find.widgetWithText(NavigationDestination, 'Calendar'));
    await showsSoon(tester, find.widgetWithText(FilterChip, 'Home'));
    File('${dir.path}/home.ics').deleteSync();
    await rescan();
    expect(find.byType(NavigationBar), findsNothing);
    File('${dir.path}/home.ics').writeAsStringSync(newCalendarText('Home'));
    await rescan();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });
}
