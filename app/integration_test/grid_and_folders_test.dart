import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truce_editor/file_page/ui/file_screen.dart';
import 'package:truce_editor/files/file_colors.dart';
import 'package:truce_editor/files/ui/all_files_view.dart';
import 'package:truce_editor/files/ui/file_sections.dart';
import 'package:truce_editor/files/ui/home_view_button.dart';
import 'package:truce_editor/files/ui/listed_file_card.dart';
import 'package:truce_editor/folders/folder_actions.dart';
import 'package:truce_editor/folders/folders_controller.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of the files grid and the folders, in the real app on
/// the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/grid_and_folders_test.dart
/// -d linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  /// Pins the file [title] from the grid.
  Future<void> pin(WidgetTester tester, String title) async {
    await tester.longPress(find.text(title));
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.text('Pin'));
    await tester.waitFor(find.byTooltip('Pinned'));
  }

  testApp('a damaged folder list says so and offers nothing to do on it', (
    tester,
  ) async {
    app.damageFolderList();
    await app.launch(tester);

    await tester.waitFor(find.text('The saved folder list is damaged.'));
    expect(find.byTooltip('New file'), findsNothing);
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh)),
      isA<IconButton>().having(
        (button) => button.onPressed,
        'onPressed',
        isNull,
      ),
    );
  });

  testApp('deletes a document and undoes it', (tester) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openFile('Plan');

    await tester.chooseInMenu('Delete file');
    await tester.waitForInPlace(find.text('Undo'));
    expect(app.file('plan.md').existsSync(), isFalse);
    await tester.tapAndSettle(find.text('Undo'));

    await tester.waitForFile(app.file('plan.md'), '# Plan\nv1\n');
    await tester.waitFor(find.text('Plan'));
  });

  testApp('pins a document from the grid', (tester) async {
    app.write('plan.md', '# Plan\n');
    app.write('ideas.md', '# Ideas\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));
    expect(find.text('Recently edited'), findsNothing);

    await pin(tester, 'Plan');

    // In its own section, above the others.
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Pinned'), lessThan(top('Plan')));
    expect(top('Plan'), lessThan(top('Recently edited')));
    expect(top('Recently edited'), lessThan(top('Ideas')));
    // A pin is this device's view, not synced with the folder.
    expect(app.folder('.truce').existsSync(), isFalse);
  });

  testApp('All shows every document, by name under each subfolder, as '
      'cards or a list', (tester) async {
    app.write('b.md', '# Bee\n');
    app.write('work/a.md', '# Ant\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Bee'));
    // Home leaves nothing out, so it offers no "Switch to all files".
    expect(find.text('Switch to all files', skipOffstage: false), findsNothing);

    await pickInView(tester, 'All files');
    await pickInView(tester, 'By name');
    await tester.waitFor(find.text('Ant'));
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    double heading(String text) => tester
        .getTopLeft(
          find.descendant(
            of: find.byType(FilesHeading),
            matching: find.text(text),
          ),
        )
        .dy;
    expect(heading('Documents'), lessThan(top('Bee')));
    expect(top('Bee'), lessThan(heading('Documents/work')));
    expect(heading('Documents/work'), lessThan(top('Ant')));

    await pickInView(tester, 'As list');
    expect(find.byType(ListTile), findsNWidgets(2));
    await tester.openFile('Ant');
    await tester.waitFor(find.byType(FileScreen));
  });

  testApp('Recently edited shows as many documents as set, All the rest', (
    tester,
  ) async {
    for (var day = 1; day <= 21; day++) {
      app.write('d$day.md', '# Day $day\n');
      app.file('d$day.md').setLastModifiedSync(DateTime(2026, 10, day));
    }
    await tester.addFolder(app);
    await tester.waitFor(find.text('Day 21'));

    await tester.chooseInMenu('Settings');
    await tester.tapAndSettle(find.text('Recently edited: how many'));
    await tester.tapAndSettle(find.text('20'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The files' own scroll view, not the folder chips'.
    Finder files() => find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Switch to all files'),
      300,
      scrollable: files(),
    );
    expect(find.text('Day 2'), findsOne);
    expect(find.text('Day 1'), findsNothing);
    await tester.tapAndSettle(find.text('Switch to all files'));
    await tester.scrollUntilVisible(
      find.text('Day 1'),
      300,
      scrollable: files(),
    );
  });

  testApp('Recently edited leaves out files older than the age limit', (
    tester,
  ) async {
    final now = DateTime.now();
    app.write('new.md', '# New\n');
    app
        .file('new.md')
        .setLastModifiedSync(now.subtract(const Duration(days: 1)));
    app.write('old.md', '# Old\n');
    app
        .file('old.md')
        .setLastModifiedSync(now.subtract(const Duration(days: 20)));
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));

    await tester.chooseInMenu('Settings');
    await tester.tapAndSettle(find.text('Recently edited: how far back'));
    await tester.tapAndSettle(find.text('Last 10 days'));
    expect(find.text('Last 10 days'), findsOne);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('New'), findsOne);
    expect(find.text('Old'), findsNothing);
    await tester.tapAndSettle(find.text('Switch to all files'));
    await tester.waitFor(find.text('Old'));
  });

  testApp('All by name builds only the cards near the screen', (tester) async {
    for (var i = 100; i < 220; i++) {
      app.write('n$i.md', '# Note $i\n');
    }
    await tester.addFolder(app);
    await tester.waitFor(find.text('Switch to all files', skipOffstage: false));
    await tester.scrollUntilVisible(
      find.text('Switch to all files'),
      600,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tapAndSettle(find.text('Switch to all files'));
    await pickInView(tester, 'By name');

    expect(find.text('Note 100'), findsOne);
    final built = find.descendant(
      of: find.byType(AllFilesView),
      matching: find.byType(ListedFileCard, skipOffstage: false),
      skipOffstage: false,
    );
    expect(built.evaluate().length, lessThan(100));
  });

  testApp('pins a document several levels deep from the grid', (tester) async {
    app.write('a/b/c/plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));

    await pin(tester, 'Plan');

    expect(app.namesIn('a/b/c'), ['plan.md']);
  });

  testApp("a listed row's color scrolls inside the list, not under the "
      'folder filter', (tester) async {
    app.write('plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));
    await tester.colorFile('Plan', 'teal');
    await pickInView(tester, 'All files');
    await pickInView(tester, 'As list');

    final row = find.byType(ListTile);
    final tint = fileTint('teal', Theme.of(tester.element(row)).colorScheme);
    // The color is drawn on the nearest Material: inside the scroll view
    // it is clipped there, outside it would show under the filter bar.
    final material = find
        .ancestor(of: row, matching: find.byType(Material))
        .first;
    expect(tester.widget<Material>(material).color, tint);
    expect(
      find.ancestor(of: material, matching: find.byType(CustomScrollView)),
      findsOne,
    );
  });

  testApp('an open document shows its color and last edit', (tester) async {
    app.write('plan.md', '# Plan\n\n---\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));
    await tester.colorFile('Plan', 'teal');

    await tester.openFile('Plan');

    final screen = find.byType(FileScreen);
    await tester.waitFor(screen);
    await tester.chooseMode('Visual edit');
    final scheme = Theme.of(tester.element(screen)).colorScheme;
    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: screen, matching: find.byType(Scaffold)),
    );
    final tint = fileTint('teal', scheme)!;
    expect(scaffold.backgroundColor, tint);
    expect(find.textContaining('Edited '), findsOne);
    // The separator's line follows the tint, as the text does.
    final separator = find.descendant(
      of: screen,
      matching: find.byType(Divider),
    );
    expect(
      Theme.of(tester.element(separator)).colorScheme.outlineVariant,
      tintedTheme(
        Theme.of(tester.element(screen)),
        tint,
      ).colorScheme.outlineVariant,
    );
  });

  testApp('warns about an unsynced folder in full only in Folders', (
    tester,
  ) async {
    Directory('${app.files.path}/.stfolder').deleteSync();
    await app.launch(tester);
    await tester.waitFor(find.text('Add folder'));
    await tester.tapAndSettle(find.text('Add folder').last);
    await tester.tapAndSettle(find.text('Syncthing'));
    await tester.tapAndSettle(find.text('Continue with this folder'));
    await tester.tapAndSettle(find.text('Next'));
    await tester.tapAndSettle(find.text('Add'));

    await tester.waitFor(find.byTooltip('Not synced by Syncthing'));
    expect(find.textContaining('may not reach'), findsNothing);

    await tester.tapAndSettle(find.byTooltip('Manage folders'));
    await tester.waitFor(find.textContaining('may not reach'));
  });

  testApp('reorders folders by dragging, and the chips follow', (tester) async {
    await tester.addFolder(app);
    await tester.addWorkFolder();
    double left(String chip) =>
        tester.getTopLeft(find.widgetWithText(FilterChip, chip)).dx;
    expect(left('Documents'), lessThan(left('Work')));

    await tester.tapAndSettle(find.byTooltip('Manage folders'));
    final handle = find.byIcon(Icons.drag_handle);
    await tester.timedDrag(
      handle.last,
      tester.getCenter(handle.first) - tester.getCenter(handle.last),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(left('Work'), lessThan(left('Documents')));
  });

  testApp('removes a folder from the app, keeping its files', (tester) async {
    app.write('plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));

    await tester.tapAndSettle(find.byTooltip('Manage folders'));
    await tester.tapAndSettle(find.byTooltip('Remove from app'));
    await tester.tapAndSettle(find.text('Remove'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.waitFor(find.text('Add folder'));
    expect(app.file('plan.md').existsSync(), isTrue);
  });

  group('removing a folder', () {
    setUp(() => app.write('home/b.md', '# B\n'));

    /// Removes the one folder from the app; returns at once, the removal
    /// goes on.
    Future<Object?> remove(WidgetTester tester) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      );
      final folder = container.read(foldersProvider).value!.single;
      return container.read(folderActionsProvider).remove(folder);
    }

    testApp('closes its open file without promising its edits', (tester) async {
      await tester.addFolder(app);
      await tester.openFile('B');

      await tester.runAsync(() => remove(tester));

      await tester.waitFor(
        find.text(
          'The file closed because its folder was removed from the app.',
        ),
      );
      await tester.waitForNoteClosed();
      expect(find.textContaining('edits are kept'), findsNothing);
    });

    testApp('waits for the last save of a file just closed', (tester) async {
      await tester.addFolder(app);
      await tester.openFile('B');
      await tester.typeOver('# B\nmine');

      // Gone without leaving, as when its route is removed: its edits are
      // saved as it goes, before the folder goes.
      final screen = tester.element(find.byType(FileScreen));
      Navigator.of(screen).removeRoute(ModalRoute.of(screen)!);
      await tester.pump();
      final removed = remove(tester);

      await tester.runAsync(() => removed);
      await tester.waitForFile(app.file('home/b.md'), '# B\nmine');
    });
  });
}

/// Picks [item] in home's view menu.
Future<void> pickInView(WidgetTester tester, String item) async {
  await tester.tapAndSettle(find.byType(HomeViewButton));
  await tester.tapAndSettle(find.text(item).last);
}
