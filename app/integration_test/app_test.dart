import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truce_editor/notes/note_colors.dart';
import 'package:truce_editor/notes/ui/note_editor_screen.dart';

import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of the real app on the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test -d linux` (in CI under
/// `xvfb-run`).
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

  testWidgets('creates a note and saves what is typed', (tester) async {
    await addFolder(tester);

    await tester.tapAndSettle(find.byTooltip('New note'));
    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.tapAndSettle(find.text('Create'));
    await tester.enterText(find.byType(TextField), '# Groceries\nMilk\n');

    await tester.waitForFile(app.file('Groceries.md'), '# Groceries\nMilk\n');
    await tester.waitFor(find.byTooltip('Saved'));
  });

  testWidgets('checks a checklist item and saves it', (tester) async {
    app.file('todo.md').writeAsStringSync('# Todo\n- [ ] Call Bob\n');
    await addFolder(tester);
    await openNote(tester, 'Todo');

    await tester.tapAndSettle(find.byType(Checkbox));

    await tester.waitForFile(app.file('todo.md'), '# Todo\n- [x] Call Bob\n');
  });

  testWidgets('shows a change made by another app', (tester) async {
    app.file('plan.md').writeAsStringSync('# Plan\nv1\n');
    await addFolder(tester);
    await openNote(tester, 'Plan');

    app.file('plan.md').writeAsStringSync('# Plan\nv2 from elsewhere\n');

    await tester.waitFor(find.textContaining('v2 from elsewhere'));
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
      await tester.waitFor(shown);
      await tester.runFor(const Duration(seconds: 12));
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

  testWidgets('removes a folder from the app, keeping its files', (
    tester,
  ) async {
    app.file('plan.md').writeAsStringSync('# Plan\n');
    await addFolder(tester);
    await tester.waitFor(find.text('Plan'));

    await tester.tapAndSettle(find.byTooltip('Folders'));
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
