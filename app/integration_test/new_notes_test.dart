import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of new notes, saving, and a note's place and name, in
/// the real app on the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/new_notes_test.dart -d
/// linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  testApp('a new note gets its file on back, named by its first line', (
    tester,
  ) async {
    await tester.addFolder(app);

    await tester.typeNewNote('Groceries\nMilk\n');
    await tester.waitFor(find.text('Notes/Groceries.md'));
    await tester.runFor(const Duration(seconds: 3));
    expect(app.topFiles, isEmpty);
    await tester.pageBack();

    await tester.waitForFile(app.file('Groceries.md'), 'Groceries\nMilk\n');
    await tester.waitForNoteClosed();
    expect(find.text('Groceries'), findsOneWidget);
  });

  testApp('an empty new note leaves no file', (tester) async {
    await tester.addFolder(app);
    await tester.tapAndSettle(find.byTooltip('New note'));
    expect(find.text('Untitled'), findsWidgets);

    await tester.pageBack();
    await tester.waitFor(find.byTooltip('New note'));

    expect(app.topFiles, isEmpty);
  });

  testApp("hiding the app writes a new note's file", (tester) async {
    await tester.addFolder(app);
    await tester.typeNewNote('Idea\n');

    tester.hideAndComeBack();
    await tester.waitForFile(app.file('Idea.md'), 'Idea\n');

    await tester.typeOver('Idea\nmore\n');
    await tester.pageBack();
    await tester.waitForFile(app.file('Idea.md'), 'Idea\nmore\n');
    await tester.waitFor(find.byTooltip('New note'));
    expect(app.topFiles, hasLength(1));
  });

  testApp('saves what is typed on the device, then in the file on back', (
    tester,
  ) async {
    app.write('groceries.md', '# Groceries\n');
    await tester.addFolder(app);
    await tester.openNote('Groceries');
    await tester.typeOver('# Groceries\nMilk\n');

    await tester.waitFor(find.byTooltip(savedOnDevice));
    expect(app.file('groceries.md').readAsStringSync(), '# Groceries\n');
    await tester.pageBack();
    await tester.waitForFile(app.file('groceries.md'), '# Groceries\nMilk\n');
  });

  testApp('tapping the save icon saves in the file right away', (tester) async {
    app.write('todo.md', '# Todo\n');
    await tester.addFolder(app);
    await tester.openNote('Todo');
    await tester.typeOver('# Todo\nCall\n');
    await tester.waitFor(find.byTooltip(savedOnDevice));

    await tester.tapAndSettle(find.byTooltip(savedOnDevice));

    await tester.waitForFile(app.file('todo.md'), '# Todo\nCall\n');
    await tester.waitFor(find.byTooltip('Saved in the folder'));
  });

  testApp('Esc leaves a note and saves it in the file', (tester) async {
    app.write('todo.md', '# Todo\n');
    await tester.addFolder(app);
    await tester.openNote('Todo');
    await tester.typeOver('# Todo\nCall\n');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.waitForNoteClosed();
    await tester.waitForFile(app.file('todo.md'), '# Todo\nCall\n');
  });

  testApp('offers an empty subfolder made while the app runs', (tester) async {
    app.write('old.md', '# Old\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));

    app.folder('later').createSync();
    await tester.tapAndSettle(find.byTooltip('New note'));
    await tester.tapAndSettle(find.byTooltip(placeAndName));
    await tester.pickSubfolder('later');

    expect(find.text('later'), findsWidgets);
  });

  testApp('a new note goes into the subfolder and name picked', (tester) async {
    app.write('old.md', '# Old\n');
    app.folder('a/b/c').createSync(recursive: true);
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));

    await tester.typeNewNote('Groceries\nMilk\n');
    await tester.placeNote(subfolder: 'a/b/c', name: 'Shop');
    await tester.waitFor(find.text('Notes/a/b/c/Shop.md'));
    await tester.pageBack();

    await tester.waitForFile(app.file('a/b/c/Shop.md'), 'Groceries\nMilk\n');
    await tester.waitFor(find.byTooltip('New note'));
    expect(app.topFiles.length, 1);
  });

  testApp('a place picked while the app was hidden moves the new file', (
    tester,
  ) async {
    app.write('old.md', '# Old\n');
    app.folder('inbox').createSync();
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));
    await tester.typeNewNote('Idea\n');
    await tester.tapAndSettle(find.byTooltip(placeAndName));

    // The user switches apps with the dialog open, and comes back.
    tester.hideAndComeBack();
    await tester.waitForFile(app.file('Idea.md'), 'Idea\n');
    await tester.fillPlace(subfolder: 'inbox');

    await tester.waitForFile(app.file('inbox/Idea.md'), 'Idea\n');
    await tester.pageBack();
    await tester.waitForNoteClosed();
    expect(app.file('Idea.md').existsSync(), isFalse);
  });

  testApp('new notes go to the place set in Settings', (tester) async {
    app.write('old.md', '# Old\n');
    app.folder('inbox').createSync();
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));

    await tester.chooseInMenu('Settings');
    await tester.tapAndSettle(find.text('Default folder for new notes'));
    await tester.fillPlace(subfolder: 'inbox');
    await tester.waitFor(find.text('Notes/inbox'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.typeNewNote('Idea');
    await tester.pageBack();

    await tester.waitForFile(app.file('inbox/Idea.md'), 'Idea');
    await tester.waitFor(find.byTooltip('New note'));
  });

  testApp('moves a note to a subfolder and edits on there', (tester) async {
    app.write('plan.md', '# Plan\n');
    app.folder('done').createSync();
    await tester.addFolder(app);
    await tester.openNote('Plan');

    await tester.placeNote(subfolder: 'done');

    await tester.waitFor(find.text('Saved as Notes/done/plan.md'));
    await tester.waitForFile(app.file('done/plan.md'), '# Plan\n');
    expect(app.file('plan.md').existsSync(), isFalse);

    await tester.typeOver('# Plan\nmore\n');
    await tester.pageBack();
    await tester.waitForFile(app.file('done/plan.md'), '# Plan\nmore\n');
    expect(app.file('plan.md').existsSync(), isFalse);
  });

  testApp('renames a note', (tester) async {
    app.write('plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.openNote('Plan');

    await tester.placeNote(name: 'Ideas');

    await tester.waitForFile(app.file('Ideas.md'), '# Plan\n');
    expect(app.file('plan.md').existsSync(), isFalse);
    expect(find.text('Notes/Ideas.md'), findsOneWidget);
  });
}
