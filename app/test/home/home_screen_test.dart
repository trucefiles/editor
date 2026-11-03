import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_editor/app.dart';
import 'package:truce_editor/file_page/ui/file_screen.dart';
import 'package:truce_editor/files/file_type_selection.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/home/home_screen.dart';
import 'package:truce_editor/platform/link_opener.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_markdown/truce_markdown.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

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
    Map<String, String> files, {
    LinkOpener links = const LinkOpener(),
  }) async {
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
        linkOpenerProvider.overrideWithValue(links),
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
    final textChip = find.widgetWithText(FilterChip, 'Plain text');

    await tester.tap(textChip);
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsNothing);
    expect(find.text('List'), findsOneWidget);

    await tester.tap(textChip);
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
  });

  testWidgets('a new file of another type than the one picked shows its '
      'type too', (tester) async {
    await start(tester, {'notes.md': '# Notes'});
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Plain text'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New file'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Note'));
    await showsSoon(tester, find.byType(FileScreen));

    expect(container.read(pickedFileTypesProvider), {
      plainTextType,
      markdownType,
    });
  });

  testWidgets('the type chips stay in sight on a narrow screen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await start(tester, {'notes.md': '# Notes'});

    // Their own row starts at the left edge, whatever the folder chips
    // take; the rest of the row scrolls sideways.
    final first = tester.getRect(find.widgetWithText(FilterChip, 'Markdown'));
    expect(first.left, lessThan(24));
    expect(first.right, lessThanOrEqualTo(360));
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

  /// A calendar named Home with "Call" today from 10 for an hour.
  String homeWithCall() {
    final now = DateTime.now();
    return applyEdit(
      Calendar.read(newCalendarText('Home'))!,
      AddEvent(
        'call',
        EventDraft(
          summary: 'Call',
          start: Floating(DateTime.utc(now.year, now.month, now.day, 10)),
          end: Floating(DateTime.utc(now.year, now.month, now.day, 11)),
        ),
        at: DateTime.utc(2026, 11),
      ),
    ).text;
  }

  testWidgets("the Calendar tab's + opens the calendar with adding started", (
    tester,
  ) async {
    await start(tester, {'notes.md': '# Notes', 'home.ics': homeWithCall()});
    await tester.tap(find.widgetWithText(NavigationDestination, 'Calendar'));
    await showsSoon(tester, find.widgetWithText(FilterChip, 'Home'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add event'));
    await showsSoon(tester, find.text('New event'));
  });

  testWidgets('an event tapped in the Calendar tab shows; Edit opens its '
      'form on its calendar page', (tester) async {
    // Tall enough for the month's rows to show their events.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await start(tester, {'notes.md': '# Notes', 'home.ics': homeWithCall()});
    await tester.tap(find.widgetWithText(NavigationDestination, 'Calendar'));
    await showsSoon(tester, find.text('Call'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    expect(find.text('Open calendar'), findsOne);
    await tester.tap(find.text('Edit'));
    await showsSoon(tester, find.text('Edit event'));
    expect(find.byType(FileScreen), findsOne);
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

  testWidgets('a link opener answering after the page is gone tells '
      'nothing', (tester) async {
    final answer = Completer<bool>();
    await start(tester, {
      'notes.md': '# Notes\n\n[site](https://example.org)',
    }, links: _LateLinkOpener(answer.future));
    await tester.tap(find.text('Notes').first);
    await showsSoon(tester, find.byType(FileScreen));
    await tester.pumpAndSettle();
    // Read, where a tap opens the link.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final link = tester
        .widgetList<RichText>(find.byType(RichText))
        .expand((text) {
          final spans = <TextSpan>[];
          text.text.visitChildren((span) {
            if (span is TextSpan && span.recognizer != null) spans.add(span);
            return true;
          });
          return spans;
        })
        .firstWhere((span) => span.text == 'site');
    (link.recognizer! as TapGestureRecognizer).onTap!();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FileScreen), findsNothing);

    answer.complete(false);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No app could open https://example.org'), findsNothing);
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

/// Opens no link, answering only once [answer] completes.
final class _LateLinkOpener implements LinkOpener {
  const _LateLinkOpener(this.answer);

  final Future<bool> answer;

  @override
  Future<bool> open(Uri link) => answer;
}
