import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truce_editor/notes/note_colors.dart';
import 'package:truce_editor/notes/ui/note_editor_screen.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';

import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of the real app on the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/app_test.dart -d linux`
/// (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  Future<void> addFolder(WidgetTester tester) async {
    await app.launch(tester);
    await tester.waitFor(find.text('Add folder'));
    await tester.tapAndSettle(find.text('Add folder'));
    await tester.waitUntil(() => find.text('Add folder').evaluate().isEmpty);
  }

  Future<void> openNote(WidgetTester tester, String title) async {
    await tester.waitFor(find.text(title));
    await tester.tapAndSettle(find.text(title));
  }

  testWidgets('saves what is typed on the device, then in the file on back', (
    tester,
  ) async {
    await addFolder(tester);

    await tester.tapAndSettle(find.byTooltip('New note'));
    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.tapAndSettle(find.text('Create'));
    await tester.enterText(find.byType(TextField), '# Groceries\nMilk\n');

    await tester.waitFor(find.byTooltip('Saved on this device'));
    expect(app.file('Groceries.md').readAsStringSync(), '# Groceries\n');
    await tester.pageBack();
    await tester.waitForFile(app.file('Groceries.md'), '# Groceries\nMilk\n');
  });

  testWidgets('creates a note in an empty subfolder', (tester) async {
    app.write('old.md', '# Old\n');
    Directory('${app.notes.path}/a/b/c').createSync(recursive: true);
    await addFolder(tester);
    await tester.waitFor(find.text('Old'));

    await tester.tapAndSettle(find.byTooltip('New note'));
    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.tapAndSettle(find.text('Top level'));
    await tester.tapAndSettle(find.text('a/b/c').last);
    await tester.tapAndSettle(find.text('Create'));
    // The editor opens once the file is written and rescanned.
    await tester.waitFor(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '# Groceries\nMilk\n');
    await tester.pageBack();

    await tester.waitForFile(
      app.file('a/b/c/Groceries.md'),
      '# Groceries\nMilk\n',
    );
    expect(app.file('Groceries.md').existsSync(), isFalse);
  });

  testWidgets('checks a checklist item and saves it', (tester) async {
    app.file('todo.md').writeAsStringSync('# Todo\n- [ ] Call Bob\n');
    await addFolder(tester);
    await openNote(tester, 'Todo');

    await tester.tapAndSettle(find.byType(Checkbox));
    await tester.pageBack();

    await tester.waitForFile(app.file('todo.md'), '# Todo\n- [x] Call Bob\n');
  });

  testWidgets('shows a change made by another app', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    app.file('plan.md').writeAsStringSync('# Plan\nv1\n');
    await addFolder(tester);
    await openNote(tester, 'Plan');

    app.file('plan.md').writeAsStringSync('# Plan\nv2 from elsewhere\n');
    await tester.refocusApp();

    await tester.waitFor(find.textContaining('v2 from elsewhere'));
    expect(
      find.text('Updated with a change from another device or app'),
      findsOne,
    );
  });

  testWidgets('shows a change made before the note opened', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    app.file('plan.md').writeAsStringSync('# Plan\nv1\n');
    await addFolder(tester);
    await tester.waitFor(find.text('Plan'));

    app.file('plan.md').writeAsStringSync('# Plan\nv2 from elsewhere\n');
    await tester.tapAndSettle(find.text('Plan'));

    await tester.waitFor(find.textContaining('v2 from elsewhere'));
  });

  testWidgets('the refresh button shows new notes', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    await addFolder(tester);
    await tester.waitFor(find.byTooltip('New note'));

    app.write('new.md', '# New\n');
    await tester.tapAndSettle(find.byTooltip('Refresh'));

    await tester.waitFor(find.text('New'));
  });

  testWidgets('pulling the grid down shows new notes', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('old.md', '# Old\n');
    await addFolder(tester);
    await tester.waitFor(find.text('Old'));

    app.write('new.md', '# New\n');
    await tester.fling(find.text('Old'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    await tester.waitFor(find.text('New'));
  });

  testWidgets('the refresh button in an open note shows a change', (
    tester,
  ) async {
    await app.useRefresh(RefreshMode.manual);
    app.file('plan.md').writeAsStringSync('# Plan\nv1\n');
    await addFolder(tester);
    await openNote(tester, 'Plan');

    app.file('plan.md').writeAsStringSync('# Plan\nv2 from elsewhere\n');
    await tester.tapAndSettle(find.byTooltip('Refresh'));

    await tester.waitFor(find.textContaining('v2 from elsewhere'));
  });

  testWidgets('shows new notes and changes live, without refreshing', (
    tester,
  ) async {
    app.file('plan.md').writeAsStringSync('# Plan\nv1\n');
    await addFolder(tester);
    await tester.waitFor(find.text('Plan'));

    app.write('deep/new.md', '# New\n');
    await tester.waitFor(find.text('New'));

    await openNote(tester, 'Plan');
    app.file('plan.md').writeAsStringSync('# Plan\nv2 from elsewhere\n');
    await tester.waitFor(find.textContaining('v2 from elsewhere'));
  });

  testWidgets('switches to manual refresh in the menu', (tester) async {
    await addFolder(tester);
    await tester.waitFor(find.byTooltip('New note'));

    await tester.tapAndSettle(find.byTooltip('Show menu'));
    await tester.tapAndSettle(find.text('Refresh: Live'));
    await tester.tapAndSettle(find.text('Manual'));
    await tester.tapAndSettle(find.text('Save'));
    app.write('new.md', '# New\n');
    await tester.runFor(const Duration(seconds: 2));

    expect(find.text('New'), findsNothing);
    await tester.tapAndSettle(find.byTooltip('Show menu'));
    expect(find.text('Refresh: Manual'), findsOne);
  });

  testWidgets('never writes back a change shown in the open note', (
    tester,
  ) async {
    app.file('todo.md').writeAsStringSync('# Todo\n- [ ] milk\n');
    await addFolder(tester);
    await openNote(tester, 'Todo');
    final file = app.file('todo.md');
    final from = DateTime(2001);

    /// Changes the note elsewhere, waits until the open note shows it, and
    /// over a few rescans checks that the app leaves the file alone.
    Future<void> changeElsewhere(String text, Finder shown) async {
      file
        ..writeAsStringSync(text)
        ..setLastModifiedSync(from);
      await tester.refocusApp();
      await tester.waitFor(shown);
      for (var i = 0; i < 3; i++) {
        await tester.runFor(const Duration(seconds: 3));
        await tester.refocusApp();
      }
      expect(file.readAsStringSync(), text);
      expect(file.lastModifiedSync(), from);
    }

    // The list view, then the text view.
    await changeElsewhere(
      '# Todo\n- [x] milk\n- [ ] eggs\n',
      find.text('eggs'),
    );
    await tester.tapAndSettle(find.byTooltip('View: List'));
    await tester.tapAndSettle(find.text('Source'));
    await changeElsewhere(
      '# Todo\n- [x] milk\n- [ ] eggs\n- [ ] tea\n',
      find.textContaining('tea'),
    );
  });

  testWidgets('a new note never brings back a folder that is gone', (
    tester,
  ) async {
    await addFolder(tester);
    await tester.waitFor(find.byTooltip('New note'));
    app.notes.deleteSync();

    await tester.tapAndSettle(find.byTooltip('New note'));
    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.tapAndSettle(find.text('Create'));

    await tester.waitFor(find.text('The file or folder no longer exists.'));
    expect(app.notes.existsSync(), isFalse);
  });

  testWidgets('back keeps edits that clash as a conflict copy', (tester) async {
    app.file('plan.md').writeAsStringSync('# Plan\nv1\n');
    await addFolder(tester);
    await openNote(tester, 'Plan');

    await tester.enterText(find.byType(TextField), '# Plan\nmine\n');
    app.file('plan.md').writeAsStringSync('# Plan\nv2 from elsewhere\n');
    await tester.pageBack();

    List<File> copies() => [
      for (final file in app.notes.listSync().whereType<File>())
        if (file.path.contains('.sync-conflict-')) file,
    ];
    await tester.waitUntil(() => copies().isNotEmpty);
    expect(copies().single.readAsStringSync(), '# Plan\nmine\n');
    expect(
      app.file('plan.md').readAsStringSync(),
      '# Plan\nv2 from elsewhere\n',
    );
    await tester.waitFor(find.byTooltip('New note'));
  });

  testWidgets('hiding the app keeps clashing edits, menus stay put', (
    tester,
  ) async {
    app.file('plan.md').writeAsStringSync('# Plan\nv1\n');
    await addFolder(tester);
    await openNote(tester, 'Plan');
    await tester.enterText(find.byType(TextField), '# Plan\nmine\n');
    app.file('plan.md').writeAsStringSync('# Plan\nv2 from elsewhere\n');
    await tester.tapAndSettle(find.byTooltip('Show menu'));

    // The user switches apps and comes back.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }

    await tester.waitFor(find.textContaining('kept as a conflict copy'));
    expect(find.text('Delete note'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.text('Close'));
    await tester.waitFor(find.byTooltip('New note'));
  });

  testWidgets('an undo in a checklist goes away with the note', (tester) async {
    app.file('list.md').writeAsStringSync('# List\n- [ ] a\n- [x] b\n');
    await addFolder(tester);
    await openNote(tester, 'List');
    await tester.tapAndSettle(find.text('Clear done'));
    expect(find.text('Undo'), findsOneWidget);

    await tester.pageBack();

    await tester.waitUntil(
      () => find.byType(NoteEditorScreen).evaluate().isEmpty,
    );
    expect(find.text('Undo'), findsNothing);
    await tester.waitForFile(app.file('list.md'), '# List\n- [ ] a\n');
  });

  testWidgets('deletes a note and undoes it', (tester) async {
    app.file('plan.md').writeAsStringSync('# Plan\nv1\n');
    await addFolder(tester);
    await openNote(tester, 'Plan');

    await tester.tapAndSettle(find.byTooltip('Show menu'));
    await tester.tapAndSettle(find.text('Delete note'));
    await tester.waitFor(find.text('Undo'));
    expect(app.file('plan.md').existsSync(), isFalse);
    await tester.tapAndSettle(find.text('Undo'));

    await tester.waitForFile(app.file('plan.md'), '# Plan\nv1\n');
    await tester.waitFor(find.text('Plan'));
  });

  testWidgets('pins a note from the grid', (tester) async {
    app.file('plan.md').writeAsStringSync('# Plan\n');
    app.file('ideas.md').writeAsStringSync('# Ideas\n');
    await addFolder(tester);
    await tester.waitFor(find.text('Plan'));
    expect(find.text('Others'), findsNothing);

    await tester.longPress(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.text('Pin'));

    await tester.waitFor(find.byTooltip('Pinned'));
    // In its own section, above the others.
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Pinned'), lessThan(top('Plan')));
    expect(top('Plan'), lessThan(top('Others')));
    expect(top('Others'), lessThan(top('Ideas')));
  });

  testWidgets('warns about an unsynced folder in full only in Folders', (
    tester,
  ) async {
    await addFolder(tester);

    await tester.waitFor(find.byTooltip('Not inside a Syncthing folder'));
    expect(find.textContaining('may not reach'), findsNothing);

    await tester.tapAndSettle(find.byTooltip('Manage folders'));
    await tester.waitFor(find.textContaining('may not reach'));
  });

  testWidgets('removes a folder from the app, keeping its files', (
    tester,
  ) async {
    app.file('plan.md').writeAsStringSync('# Plan\n');
    await addFolder(tester);
    await tester.waitFor(find.text('Plan'));

    await tester.tapAndSettle(find.byTooltip('Manage folders'));
    await tester.tapAndSettle(find.byTooltip('Remove from app'));
    await tester.tapAndSettle(find.text('Remove'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.waitFor(find.text('Add folder'));
    expect(app.file('plan.md').existsSync(), isTrue);
  });

  testWidgets('reopens a note in the view it was left in', (tester) async {
    app.file('todo.md').writeAsStringSync('# Todo\n- [ ] Call Bob\n');
    await addFolder(tester);
    await openNote(tester, 'Todo');
    expect(find.byType(Checkbox), findsOneWidget);

    await tester.tapAndSettle(find.byTooltip('View: List'));
    await tester.tapAndSettle(find.text('Source'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openNote(tester, 'Todo');

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byTooltip('View: Source'), findsOneWidget);
  });

  testWidgets('an open note shows its color and last edit', (tester) async {
    app.file('plan.md').writeAsStringSync('# Plan\n');
    await addFolder(tester);
    await tester.waitFor(find.text('Plan'));
    // Right click, as with a mouse.
    await tester.tap(
      find.text('Plan'),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.byTooltip('teal'));

    await openNote(tester, 'Plan');

    final screen = find.byType(NoteEditorScreen);
    await tester.waitFor(screen);
    final scheme = Theme.of(tester.element(screen)).colorScheme;
    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: screen, matching: find.byType(Scaffold)),
    );
    expect(scaffold.backgroundColor, noteTint('teal', scheme));
    expect(find.textContaining('Edited '), findsOne);
  });

  testWidgets('renders a note as Markdown', (tester) async {
    app.file('read.md').writeAsStringSync('# Read me\n\nSome **bold** text.\n');
    await addFolder(tester);
    await openNote(tester, 'Read me');

    await tester.tapAndSettle(find.byTooltip('View: Source'));
    await tester.tapAndSettle(find.text('Rendered'));

    expect(find.byType(TextField), findsNothing);
    expect(
      find.textContaining('Some bold text.', findRichText: true),
      findsOne,
    );
  });

  testWidgets('edits a note several levels deep', (tester) async {
    app.write('a/b/c/todo.md', '# Deep\n- [ ] Call Bob\n');
    app.write('todo.md', '# Root\n');
    await addFolder(tester);

    await tester.waitFor(find.text('Notes/a/b/c'));
    await openNote(tester, 'Deep');
    expect(find.text('Notes/a/b/c'), findsOne);
    await tester.tapAndSettle(find.byType(Checkbox));
    await tester.pageBack();

    await tester.waitForFile(
      app.file('a/b/c/todo.md'),
      '# Deep\n- [x] Call Bob\n',
    );
    expect(app.file('todo.md').readAsStringSync(), '# Root\n');
  });

  testWidgets('pins a note several levels deep from the grid', (tester) async {
    app.write('a/b/c/plan.md', '# Plan\n');
    await addFolder(tester);
    await tester.waitFor(find.text('Plan'));

    await tester.longPress(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.text('Pin'));

    await tester.waitFor(find.byTooltip('Pinned'));
    expect(
      Directory('${app.notes.path}/a/b/c')
          .listSync()
          .map((entry) => entry.uri.pathSegments.last),
      ['plan.md'],
    );
  });

  testWidgets('keeps clashing edits of a deep note as a conflict copy', (
    tester,
  ) async {
    app.write('a/b/c/plan.md', '# Plan\nv1\n');
    await addFolder(tester);
    await openNote(tester, 'Plan');

    await tester.enterText(find.byType(TextField), '# Plan\nmine\n');
    app.write('a/b/c/plan.md', '# Plan\nv2 from elsewhere\n');
    await tester.pageBack();

    final deep = Directory('${app.notes.path}/a/b/c');
    List<File> copies() => [
      for (final file in deep.listSync().whereType<File>())
        if (file.path.contains('.sync-conflict-')) file,
    ];
    await tester.waitUntil(() => copies().isNotEmpty);
    expect(copies().single.readAsStringSync(), '# Plan\nmine\n');
    expect(app.notes.listSync().whereType<File>(), isEmpty);
    await tester.waitFor(find.byTooltip('Sync conflict'));
  });

  testWidgets('resolves a conflict several levels deep', (tester) async {
    app.write('a/b/c/todo.md', '# Todo\nmine\n');
    app.write(
      'a/b/c/todo.sync-conflict-20261003-134809-ABCDEFG.md',
      '# Todo\nfirst\n',
    );
    await addFolder(tester);
    await openNote(tester, 'Todo');

    await tester.waitFor(find.text('Compare'));
    await tester.tapAndSettle(find.text('Compare'));
    expect(find.text('Notes/a/b/c'), findsOne);
    await tester.tapAndSettle(find.text('Keep this').last);
    await tester.tapAndSettle(find.text('Keep'));

    await tester.waitFor(find.textContaining('Conflict resolved'));
    final deep = Directory('${app.notes.path}/a/b/c');
    expect(deep.listSync().map((entry) => entry.uri.pathSegments.last), [
      'todo.md',
    ]);
    expect(app.file('a/b/c/todo.md').readAsStringSync(), '# Todo\nfirst\n');
  });

  testWidgets('lists every conflict and resolves one from the list', (
    tester,
  ) async {
    app.write('todo.md', '# Todo\nmine\n');
    app.write('todo.sync-conflict-20261003-134809-ABCDEFG.md', '# Todo\nx\n');
    await addFolder(tester);

    await tester.waitFor(find.byTooltip('Conflicts'));
    await tester.tapAndSettle(find.byTooltip('Conflicts'));
    expect(find.text('1 other version'), findsOne);
    await tester.tapAndSettle(find.text('Todo'));
    await tester.tapAndSettle(find.text('Keep this').last);
    await tester.tapAndSettle(find.text('Keep'));

    await tester.waitFor(find.text('No sync conflicts.'));
    expect(app.file('todo.md').readAsStringSync(), '# Todo\nx\n');
  });

  testWidgets('resolves two conflict copies one by one', (tester) async {
    app.file('todo.md').writeAsStringSync('# Todo\nmine\n');
    app
        .file('todo.sync-conflict-20261003-134809-ABCDEFG.md')
        .writeAsStringSync('# Todo\nfirst\n');
    app
        .file('todo.sync-conflict-20261004-080000-ABCDEFG.md')
        .writeAsStringSync('# Todo\nsecond\n');
    await addFolder(tester);
    await openNote(tester, 'Todo');

    await tester.waitFor(find.text('Compare'));
    await tester.tapAndSettle(find.text('Compare'));
    await tester.waitFor(find.text('2 other versions, oldest first'));
    await tester.tapAndSettle(find.text('Keep this').first);
    await tester.tapAndSettle(find.text('Keep'));
    await tester.waitFor(find.textContaining('second', findRichText: true));
    expect(find.text('2 other versions, oldest first'), findsNothing);

    await tester.tapAndSettle(find.text('Keep this').first);
    await tester.tapAndSettle(find.text('Keep'));

    await tester.waitFor(find.textContaining('Conflict resolved'));
    expect(app.notes.listSync().map((entry) => entry.uri.pathSegments.last), [
      'todo.md',
    ]);
    expect(app.file('todo.md').readAsStringSync(), '# Todo\nmine\n');
  });
}
