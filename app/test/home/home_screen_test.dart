import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart'
    show CalendarDot, CalendarViews;
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/app.dart';
import 'package:truce_editor/file_page/ui/file_screen.dart';
import 'package:truce_editor/files/file_settings_controller.dart';
import 'package:truce_editor/files/file_type_selection.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/home/home_screen.dart';
import 'package:truce_editor/platform/link_opener.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_files/truce_files.dart';
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

  /// Starts the app on a folder holding [files], last changed [changed]
  /// (by default now), until [shows] shows; the folder.
  Future<Directory> start(
    WidgetTester tester,
    Map<String, String> files, {
    LinkOpener links = const LinkOpener(),
    DeviceSettings settings = DeviceSettings.standard,
    DateTime? changed,
    Finder? shows,
  }) async {
    final dir = tempFolder();
    for (final MapEntry(key: name, value: text) in files.entries) {
      final file = File('${dir.path}/$name')..writeCreatingFolders(text);
      if (changed != null) file.setLastModifiedSync(changed);
    }
    final storage = AppStorage(tempFolder().path);
    final scope = ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        loadedDeviceSettingsProvider.overrideWithValue(settings),
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
    await showsSoon(tester, shows ?? find.text('Notes'));
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

  testWidgets('a Clear chip shows in a row only while something in it is '
      'picked, and clears only that row', (tester) async {
    final dir = await start(tester, {
      'notes.md': '# Notes',
      'list.txt': 'List\nmilk',
    });
    final clear = find.widgetWithText(ActionChip, 'Clear');
    expect(clear, findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Plain text'));
    await tester.tap(find.widgetWithText(FilterChip, folderAt(dir).name));
    await tester.pumpAndSettle();
    expect(clear, findsNWidgets(2));
    expect(find.text('Notes'), findsNothing);

    // The second Clear is the type row's.
    await tester.tap(clear.last);
    await tester.pumpAndSettle();
    expect(clear, findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);

    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(clear, findsNothing);
  });

  testWidgets('a long press on a card shows its actions as a sheet: its '
      'title and place, Open, Pin and where the rest is', (tester) async {
    await start(tester, {'work/notes.md': '# Notes'});

    await tester.longPress(find.text('Notes'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Documents/work')),
      findsOne,
    );
    expect(find.descendant(of: sheet, matching: find.text('Pin')), findsOne);
    expect(
      find.descendant(
        of: sheet,
        matching: find.textContaining('Open the file to'),
      ),
      findsOne,
    );

    await tester.tap(find.descendant(of: sheet, matching: find.text('Open')));
    await showsSoon(tester, find.byType(FileScreen));
  });

  testWidgets('a right click on a card shows its actions as a menu there, '
      'the colors in a submenu', (tester) async {
    await start(tester, {'notes.md': '# Notes'});

    final at = tester.getCenter(find.text('Notes'));
    await tester.tapAt(
      at,
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    final open = find.widgetWithText(MenuItemButton, 'Open');
    expect(open, findsOne);
    expect((tester.getTopLeft(open) - at).distance, lessThan(80));
    expect(find.widgetWithText(MenuItemButton, 'Pin'), findsOne);
    expect(find.textContaining('Open the file to'), findsOne);

    // As with a mouse: the submenu opens on hover.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.moveTo(
      tester.getCenter(find.widgetWithText(SubmenuButton, 'Color')),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('No color'), findsOne);

    await tester.tap(find.widgetWithText(MenuItemButton, 'Pin'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Open'), findsNothing);
    expect(find.text('Pinned'), findsWidgets);
  });

  testWidgets('Esc closes a card\'s right-click menu and stays on home', (
    tester,
  ) async {
    await start(tester, {'notes.md': '# Notes'});

    await tester.tapAt(
      tester.getCenter(find.text('Notes')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(MenuItemButton, 'Open'), findsNothing);
    expect(find.byType(HomeScreen), findsOne);
  });

  testWidgets('with nothing edited within the age limit, home says so '
      'above Show all', (tester) async {
    await start(
      tester,
      {'notes.md': '# Notes'},
      settings: DeviceSettings.standard.copyWith(
        home: HomeSettings.standard.withRecentDays(5),
      ),
      changed: DateTime.now().subtract(const Duration(days: 10)),
      shows: find.text('Switch to all files'),
    );

    expect(find.text('Nothing edited in the last 5 days.'), findsOne);
    expect(find.text('Notes'), findsNothing);
  });

  testWidgets('the title names the view; Back in All files returns to '
      'Home', (tester) async {
    await start(
      tester,
      {'notes.md': '# Notes', 'old.md': '# Old'},
      settings: DeviceSettings.standard.copyWith(
        home: HomeSettings.standard.copyWith(recentCount: 1),
      ),
      shows: find.text('Switch to all files'),
    );
    Finder title(String text) =>
        find.descendant(of: find.byType(AppBar), matching: find.text(text));
    expect(title('Home'), findsOne);

    await tester.tap(find.text('Switch to all files'));
    await tester.pumpAndSettle();
    expect(title('All files'), findsOne);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(title('Home'), findsOne);
    expect(find.byType(HomeScreen), findsOne);
  });

  testWidgets('with an age limit, the heading of the recent files says '
      'it', (tester) async {
    final dir = await start(
      tester,
      {'notes.md': '# Notes', 'pinned.md': '# Pinned'},
      settings: DeviceSettings.standard.copyWith(
        home: HomeSettings.standard.withRecentDays(10),
      ),
      shows: find.text('Pinned'),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    // Headings show once something is pinned.
    await tester.runAsync(
      () => container.read(fileSettingsProvider.notifier).edit((
        folder: folderAt(dir).id,
        path: RelPath.parse('pinned.md')!,
      ), (settings) => settings.withPinned(pinned: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edited in the last 10 days'), findsOne);
    expect(find.text('Recently edited'), findsNothing);
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
    await tester.tap(find.widgetWithText(ListTile, 'Document'));
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

    await tester.tap(find.widgetWithText(NavigationDestination, 'Calendars'));
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

  /// Shows the Calendar tab of the started app, once its calendars show.
  Future<void> showCalendarTab(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(NavigationDestination, 'Calendars'));
    await showsSoon(tester, find.widgetWithText(FilterChip, 'Home'));
    await tester.pumpAndSettle();
  }

  testWidgets("the Calendar tab's button opens its only calendar, starting "
      'nothing', (tester) async {
    await start(tester, {'notes.md': '# Notes', 'home.ics': homeWithCall()});
    await showCalendarTab(tester);

    await tester.tap(find.byTooltip('Open calendar'));
    await showsSoon(tester, find.byType(FileScreen));
    await tester.pumpAndSettle();

    expect(find.text('Open which calendar?'), findsNothing);
    expect(find.text('New event'), findsNothing);
  });

  testWidgets("the Calendar tab's button asks which calendar to open, each "
      'with its color', (tester) async {
    await start(tester, {
      'notes.md': '# Notes',
      'home.ics': newCalendarText('Home'),
      'work.ics': newCalendarText('Work'),
    });
    await showCalendarTab(tester);

    await tester.tap(find.byTooltip('Open calendar'));
    await tester.pumpAndSettle();
    final dialog = find.byType(SimpleDialog);
    expect(find.text('Open which calendar?'), findsOne);
    expect(
      find.descendant(of: dialog, matching: find.byType(CalendarDot)),
      findsNWidgets(2),
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('Work')));
    await showsSoon(tester, find.byType(FileScreen));
    await tester.pumpAndSettle();

    expect(find.text('New event'), findsNothing);
    expect(find.text('Work'), findsWidgets);
  });

  testWidgets('a tap on a free day in the Calendar tab says to open a '
      'calendar; Open opens it', (tester) async {
    await start(tester, {
      'notes.md': '# Notes',
      'home.ics': newCalendarText('Home'),
    });
    await showCalendarTab(tester);

    await tester.tap(find.byType(CalendarViews<ListedFile>));
    await tester.pumpAndSettle();
    expect(find.text('Open one calendar to edit'), findsOne);
    expect(find.text('New event'), findsNothing);

    await tester.tap(find.text('Open'));
    await showsSoon(tester, find.byType(FileScreen));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsNothing);
  });

  testWidgets('a drag over free days in the Calendar tab says to open a '
      'calendar and adds nothing', (tester) async {
    final dir = await start(tester, {
      'notes.md': '# Notes',
      'home.ics': newCalendarText('Home'),
    });
    await showCalendarTab(tester);

    final from = tester.getCenter(find.text('10')) + const Offset(0, 40);
    final to = tester.getCenter(find.text('12')) + const Offset(0, 40);
    final gesture = await tester.startGesture(
      from,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy((to - from) / 10);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Open one calendar to edit'), findsOne);
    expect(find.text('New event'), findsNothing);
    expect(find.byType(FileScreen), findsNothing);
    expect(
      File('${dir.path}/home.ics').readAsStringSync(),
      newCalendarText('Home'),
    );
  });

  testWidgets('an event tapped in the Calendar tab shows; Edit opens its '
      'form on its calendar page', (tester) async {
    // Tall enough for the month's rows to show their events.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await start(tester, {'notes.md': '# Notes', 'home.ics': homeWithCall()});
    await tester.tap(find.widgetWithText(NavigationDestination, 'Calendars'));
    await showsSoon(tester, find.text('Call'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    expect(find.text('Open calendar'), findsOne);
    await tester.tap(find.text('Edit'));
    await showsSoon(tester, find.text('Edit event'));
    expect(find.byType(FileScreen), findsOne);

    // Esc closes the event form, as on every page, and leaves the
    // calendar's page under it open.
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Edit event'), findsNothing);
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

  testWidgets('on a phone, Redo is in the menu, so the bar keeps room for '
      'the title', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await start(tester, {'notes.md': '# Notes\n- [ ] milk\n'});

    await tester.tap(find.text('Notes').first);
    await showsSoon(tester, find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Redo'), findsNothing);

    await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
    await tester.pumpAndSettle();
    expect(find.text('Redo'), findsOne);
  });

  testWidgets('on a wide window, Redo is in the bar', (tester) async {
    await start(tester, {'notes.md': '# Notes\n- [ ] milk\n'});

    await tester.tap(find.text('Notes').first);
    await showsSoon(tester, find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Redo'), findsOne);
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

    await tester.tap(find.widgetWithText(NavigationDestination, 'Calendars'));
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
