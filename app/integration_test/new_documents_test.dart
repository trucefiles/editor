import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of new documents, saving, and a document's place and name, in
/// the real app on the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/new_documents_test.dart -d
/// linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  testApp('a new document gets its file on back, named by its first line', (
    tester,
  ) async {
    await tester.addFolder(app);

    await tester.typeNewNote('Groceries\nMilk');
    await tester.waitFor(find.text('Documents/Groceries.md'));
    await tester.runFor(const Duration(seconds: 3));
    expect(app.topFiles, isEmpty);
    await tester.pageBack();

    await tester.waitForFile(app.file('Groceries.md'), 'Groceries\n\nMilk\n');
    await tester.waitForNoteClosed();
    expect(find.text('Groceries'), findsOneWidget);
  });

  testApp('an empty new document leaves no file', (tester) async {
    await tester.addFolder(app);
    await tester.tapAndSettle(find.byTooltip('New document'));
    expect(find.text('Untitled'), findsWidgets);

    await tester.pageBack();
    await tester.waitFor(find.byTooltip('New document'));

    expect(app.topFiles, isEmpty);
  });

  testApp("hiding the app writes a new document's file", (tester) async {
    await tester.addFolder(app);
    await tester.typeNewNote('Idea');

    tester.hideAndComeBack();
    await tester.waitForFile(app.file('Idea.md'), 'Idea\n');

    await tester.typeOver('Idea\nmore\n');
    await tester.pageBack();
    await tester.waitForFile(app.file('Idea.md'), 'Idea\nmore\n');
    await tester.waitFor(find.byTooltip('New document'));
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

  testApp('Esc leaves a document and saves it in the file', (tester) async {
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
    await tester.tapAndSettle(find.byTooltip('New document'));
    await tester.tapAndSettle(find.byTooltip(placeAndName));
    await tester.pickSubfolder('later');

    expect(find.text('later'), findsWidgets);
  });

  testApp('a new document goes into the subfolder and name picked', (
    tester,
  ) async {
    app.write('old.md', '# Old\n');
    app.folder('a/b/c').createSync(recursive: true);
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));

    await tester.typeNewNote('Groceries\nMilk');
    await tester.placeNote(subfolder: 'a/b/c', name: 'Shop');
    await tester.waitFor(find.text('Documents/a/b/c/Shop.md'));
    await tester.pageBack();

    await tester.waitForFile(app.file('a/b/c/Shop.md'), 'Groceries\n\nMilk\n');
    await tester.waitFor(find.byTooltip('New document'));
    expect(app.topFiles.length, 1);
  });

  testApp('a new document goes into a typed new subfolder', (tester) async {
    app.write('old.md', '# Old\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));

    await tester.typeNewNote('Plans');
    await tester.tapAndSettle(find.byTooltip(placeAndName));
    await tester.typeSubfolder('2026/spring');
    await tester.tapAndSettle(find.text('OK'));
    await tester.waitFor(find.text('Documents/2026/spring/Plans.md'));
    await tester.pageBack();

    await tester.waitForFile(app.file('2026/spring/Plans.md'), 'Plans\n');
  });

  testApp('a place picked while the app was hidden moves the new file', (
    tester,
  ) async {
    app.write('old.md', '# Old\n');
    app.folder('inbox').createSync();
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));
    await tester.typeNewNote('Idea');
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

  testApp('new documents go to the place set in Settings', (tester) async {
    app.write('old.md', '# Old\n');
    app.folder('inbox').createSync();
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));

    await tester.chooseInMenu('Settings');
    await tester.tapAndSettle(find.text('Default folder for new documents'));
    await tester.fillPlace(subfolder: 'inbox');
    await tester.waitFor(find.text('Documents/inbox'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.typeNewNote('Idea');
    await tester.pageBack();

    await tester.waitForFile(app.file('inbox/Idea.md'), 'Idea\n');
    await tester.waitFor(find.byTooltip('New document'));
  });

  testApp('moves a document to a subfolder and edits on there', (tester) async {
    app.write('plan.md', '# Plan\n');
    app.folder('done').createSync();
    await tester.addFolder(app);
    await tester.openNote('Plan');

    await tester.placeNote(subfolder: 'done');

    await tester.waitFor(find.text('Saved as Documents/done/plan.md'));
    await tester.waitForFile(app.file('done/plan.md'), '# Plan\n');
    expect(app.file('plan.md').existsSync(), isFalse);

    await tester.typeOver('# Plan\nmore\n');
    await tester.pageBack();
    await tester.waitForFile(app.file('done/plan.md'), '# Plan\nmore\n');
    expect(app.file('plan.md').existsSync(), isFalse);
  });

  testApp('renames a document', (tester) async {
    app.write('plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.openNote('Plan');

    await tester.placeNote(name: 'Ideas');

    await tester.waitForFile(app.file('Ideas.md'), '# Plan\n');
    expect(app.file('plan.md').existsSync(), isFalse);
    expect(find.text('Documents/Ideas.md'), findsOneWidget);
  });
}
