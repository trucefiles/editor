import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/document_page/ui/document_screen.dart';
import 'package:truce_editor/documents/document_colors.dart';
import 'package:truce_editor/documents/ui/all_documents_screen.dart';
import 'package:truce_editor/documents/ui/document_sections.dart';
import 'package:truce_editor/documents/ui/listed_document_card.dart';
import 'package:truce_editor/folders/folder_actions.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_test_support/truce_test_support.dart' show path;

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of the documents grid and the folders, in the real app on
/// the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/grid_and_folders_test.dart
/// -d linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  /// Pins the document [title] from the grid.
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
    expect(find.byTooltip('New document'), findsNothing);
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
    await tester.openDocument('Plan');

    await tester.chooseInMenu('Delete document');
    await tester.waitFor(find.text('Undo'));
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
    expect(find.text('Recent'), findsNothing);

    await pin(tester, 'Plan');

    // In its own section, above the others.
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Pinned'), lessThan(top('Plan')));
    expect(top('Plan'), lessThan(top('Recent')));
    expect(top('Recent'), lessThan(top('Ideas')));
    // A pin is this device's view, not synced with the folder.
    expect(app.folder('.truce').existsSync(), isFalse);
  });

  testApp('All shows every document, by name under each subfolder, as '
      'cards or a list', (tester) async {
    app.write('b.md', '# Bee\n');
    app.write('work/a.md', '# Ant\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Bee'));

    await tester.tapAndSettle(find.text('Show all'));
    await tester.tapAndSettle(find.byTooltip('Sort'));
    await tester.tapAndSettle(find.text('By name'));
    await tester.waitFor(find.text('Ant'));
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    double heading(String text) => tester
        .getTopLeft(
          find.descendant(
            of: find.byType(DocumentsHeading),
            matching: find.text(text),
          ),
        )
        .dy;
    expect(heading('Documents'), lessThan(top('Bee')));
    expect(top('Bee'), lessThan(heading('Documents/work')));
    expect(heading('Documents/work'), lessThan(top('Ant')));

    await tester.tapAndSettle(find.byTooltip('Show as list'));
    expect(find.byType(ListTile), findsNWidgets(2));
    await tester.openDocument('Ant');
    await tester.waitFor(find.byType(DocumentScreen));
  });

  testApp('Recent shows as many documents as set, All the rest', (
    tester,
  ) async {
    for (var day = 1; day <= 21; day++) {
      app.write('d$day.md', '# Day $day\n');
      app.file('d$day.md').setLastModifiedSync(DateTime(2026, 10, day));
    }
    await tester.addFolder(app);
    await tester.waitFor(find.text('Day 21'));

    await tester.chooseInMenu('Settings');
    await tester.tapAndSettle(find.text('Recent documents on home'));
    await tester.tapAndSettle(find.text('20'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The documents' own scroll view, not the folder chips'.
    Finder documents() => find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Show all'),
      300,
      scrollable: documents(),
    );
    expect(find.text('Day 2'), findsOne);
    expect(find.text('Day 1'), findsNothing);
    await tester.tapAndSettle(find.text('Show all'));
    await tester.scrollUntilVisible(
      find.text('Day 1'),
      300,
      scrollable: documents(),
    );
  });

  testApp('All by name builds only the cards near the screen', (tester) async {
    for (var i = 100; i < 220; i++) {
      app.write('n$i.md', '# Note $i\n');
    }
    await tester.addFolder(app);
    await tester.waitFor(find.text('Show all', skipOffstage: false));
    await tester.scrollUntilVisible(
      find.text('Show all'),
      600,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tapAndSettle(find.text('Show all'));
    await tester.tapAndSettle(find.byTooltip('Sort'));
    await tester.tapAndSettle(find.text('By name'));

    expect(find.text('Note 100'), findsOne);
    final built = find.descendant(
      of: find.byType(AllDocumentsScreen),
      matching: find.byType(ListedDocumentCard, skipOffstage: false),
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

  testApp('an open document shows its color and last edit', (tester) async {
    app.write('plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));
    // Right click, as with a mouse.
    await tester.tap(
      find.text('Plan'),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.byTooltip('teal'));

    await tester.openDocument('Plan');

    final screen = find.byType(DocumentScreen);
    await tester.waitFor(screen);
    final scheme = Theme.of(tester.element(screen)).colorScheme;
    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: screen, matching: find.byType(Scaffold)),
    );
    expect(scaffold.backgroundColor, documentTint('teal', scheme));
    expect(find.textContaining('Edited '), findsOne);
  });

  testApp('warns about an unsynced folder in full only in Folders', (
    tester,
  ) async {
    await tester.addFolder(app);

    await tester.waitFor(find.byTooltip('Not inside a Syncthing folder'));
    expect(find.textContaining('may not reach'), findsNothing);

    await tester.tapAndSettle(find.byTooltip('Manage folders'));
    await tester.waitFor(find.textContaining('may not reach'));
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

  group('narrowing a folder', () {
    setUp(() {
      app
        ..write('notes/a.md', '# A\n')
        ..write('home/b.md', '# B\n');
    });

    /// Changes the one folder to show only `notes`; returns at once, the
    /// change goes on.
    Future<Object?> narrow(WidgetTester tester) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      );
      final folder = container.read(foldersProvider).value!.single;
      return container
          .read(folderActionsProvider)
          .change(folder.copyWith(selection: Selection.of([path('notes')])));
    }

    testApp('closes a document it no longer shows, with the screen on top, '
        'keeping the edits', (tester) async {
      await tester.addFolder(app);
      await tester.openDocument('B');
      await tester.typeOver('# B\nmine');
      await tester.chooseInMenu('Backups');

      await narrow(tester);

      await tester.waitFor(
        find.text(
          'The document is no longer in a folder shown here. Your edits '
          'are kept.',
        ),
      );
      await tester.waitForNoteClosed();
      await tester.waitForFile(app.file('home/b.md'), '# B\nmine');
      await tester.waitFor(find.text('A'));
      expect(find.text('B'), findsNothing);
    });

    testApp('removing its folder closes a document without promising its '
        'edits', (tester) async {
      await tester.addFolder(app);
      await tester.openDocument('B');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      );
      final folder = container.read(foldersProvider).value!.single;

      await tester.runAsync(
        () => container.read(folderActionsProvider).remove(folder),
      );

      await tester.waitFor(
        find.text('The folder was removed, so the document closed.'),
      );
      await tester.waitForNoteClosed();
      expect(find.textContaining('Your edits are kept'), findsNothing);
    });

    testApp('waits for the last save of a document just closed', (
      tester,
    ) async {
      await tester.addFolder(app);
      await tester.openDocument('B');
      await tester.typeOver('# B\nmine');

      // Gone without leaving, as when its route is removed: its edits are
      // saved as it goes, before the folder changes.
      final screen = tester.element(find.byType(DocumentScreen));
      Navigator.of(screen).removeRoute(ModalRoute.of(screen)!);
      await tester.pump();
      final changed = narrow(tester);

      await tester.runAsync(() => changed);
      await tester.waitForFile(app.file('home/b.md'), '# B\nmine');
    });
  });
}
