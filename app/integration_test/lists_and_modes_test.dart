import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_editor/super_editor.dart';

import 'package:truce_editor/documents/ui/document_card.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_target.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of lists and a document's modes, in the real app on
/// the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/lists_and_modes_test.dart
/// -d linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  testApp('checks a checklist item and saves it', (tester) async {
    app.write('todo.md', '# Todo\n- [ ] Call Bob\n');
    await tester.addFolder(app);
    await tester.openNote('Todo');

    await tester.tapAndSettle(find.byType(Checkbox));
    await tester.pageBack();

    await tester.waitForFile(app.file('todo.md'), '# Todo\n- [x] Call Bob\n');
  });

  testApp('edits a document several levels deep', (tester) async {
    app.write('a/b/c/todo.md', '# Deep\n- [ ] Call Bob\n');
    app.write('todo.md', '# Root\n');
    await tester.addFolder(app);

    await tester.waitFor(find.text('Documents/a/b/c'));
    await tester.openNote('Deep');
    expect(find.text('Documents/a/b/c/todo.md'), findsOne);
    await tester.tapAndSettle(find.byType(Checkbox));
    await tester.pageBack();

    await tester.waitForFile(
      app.file('a/b/c/todo.md'),
      '# Deep\n- [x] Call Bob\n',
    );
    expect(app.file('todo.md').readAsStringSync(), '# Root\n');
  });

  testApp('an undo in a checklist goes away with the document', (tester) async {
    app.write('list.md', '# List\n- [ ] a\n- [x] b\n');
    await tester.addFolder(app);
    await tester.openNote('List');
    await tester.chooseInMenu('Clear checked items now');
    expect(find.text('Undo'), findsOneWidget);

    await tester.pageBack();

    await tester.waitForNoteClosed();
    expect(find.text('Undo'), findsNothing);
    await tester.waitForFile(app.file('list.md'), '# List\n- [ ] a\n');
  });

  testApp('a document keeps its Done section choice, on this device only', (
    tester,
  ) async {
    app.write('list.md', '# List\n- [ ] a\n- [x] b\n');
    await tester.addFolder(app);
    await tester.openNote('List');
    expect(find.text('Done (1)'), findsNothing);

    await tester.chooseCheckedItems('Show at end');
    await tester.waitFor(find.text('Done (1)'));
    await tester.pageBack();
    await tester.waitForNoteClosed();
    await tester.openNote('List');

    expect(find.text('Done (1)'), findsOneWidget);
    expect(app.folder('.truce').existsSync(), isFalse);
  });

  testApp('checking moves the item to the end in the file, by default', (
    tester,
  ) async {
    app.write('list.md', '# List\n- [x] a\n- [ ] b\n- [ ] c\n');
    await tester.addFolder(app);
    await tester.openNote('List');

    await tester.tapAndSettle(find.byType(Checkbox).at(1));
    await tester.pageBack();

    await tester.waitForFile(
      app.file('list.md'),
      '# List\n- [x] a\n- [ ] c\n- [x] b\n',
    );
  });

  testApp('the menu moves checked items to the end now', (tester) async {
    app.write('list.md', '# List\n- [x] a\n- [ ] b\n');
    await tester.addFolder(app);
    await tester.openNote('List');

    await tester.chooseInMenu('Move checked items to end now');
    await tester.pageBack();

    await tester.waitForFile(app.file('list.md'), '# List\n- [ ] b\n- [x] a\n');
  });

  testApp('in Read, the menu moves checked items to the end and shows it; '
      'in Markdown edit it offers only the setting', (tester) async {
    app.write('list.md', '# List\n- [x] a\n- [ ] b\n');
    await tester.addFolder(app);
    await tester.openNote('List');
    await tester.chooseMode('Read');

    await tester.chooseInMenu('Move checked items to end now');
    expect(
      tester.getTopLeft(find.text('b')).dy,
      lessThan(tester.getTopLeft(find.text('a')).dy),
    );

    await tester.chooseMode('Markdown edit');
    await tester.tapAndSettle(find.byTooltip('Show menu'));
    expect(find.text('Checked items: Move to end'), findsOneWidget);
    expect(find.text('Clear checked items now'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.pageBack();

    await tester.waitForFile(app.file('list.md'), '# List\n- [ ] b\n- [x] a\n');
    expect(app.conflictCopies(), isEmpty);
  });

  testApp('reopens a document in the mode it was left in', (tester) async {
    app.write('todo.md', '# Todo\n- [ ] Call Bob\n');
    await tester.addFolder(app);
    await tester.openNote('Todo');
    expect(find.byType(Checkbox), findsOneWidget);

    await tester.chooseMode('Markdown edit');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.openNote('Todo');

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byTooltip('Mode: Markdown edit'), findsOneWidget);
  });

  testApp('first shows a document without checkboxes in Read', (tester) async {
    app.write('read.md', '# Read me\n\nSome **bold** text.\n');
    await tester.addFolder(app);

    await tester.openNote('Read me');

    expect(find.byTooltip('Mode: Read'), findsOne);
    expect(find.byType(SuperEditor), findsNothing);
    expect(
      find.textContaining('Some bold text.', findRichText: true),
      findsOne,
    );
  });

  testApp('Ctrl+1, 2 and 3 switch between Visual, Markdown and Read', (
    tester,
  ) async {
    app.write('todo.md', '# Todo\n- [ ] Call\n');
    await tester.addFolder(app);
    await tester.openNote('Todo');

    await tester.pressCtrl(LogicalKeyboardKey.digit3);
    expect(find.byTooltip('Mode: Read'), findsOne);
    await tester.pressCtrl(LogicalKeyboardKey.digit2);
    expect(find.byTooltip('Mode: Markdown edit'), findsOne);
    await tester.pressCtrl(LogicalKeyboardKey.digit1);
    expect(find.byTooltip('Mode: Visual edit'), findsOne);
  });

  testApp('Ctrl with + or =, - and 0 zoom document text, on every screen', (
    tester,
  ) async {
    app.write('todo.md', '# Todo\n- [ ] Call\n');
    await tester.addFolder(app);
    await tester.openNote('Todo');

    /// How large the document shows text of 10 px.
    double scaled() =>
        MediaQuery.textScalerOf(tester.element(find.byType(SuperEditor)))
            .scale(10);
    final base = scaled();

    /// How large the app's own text (the app bar) shows text of 10 px.
    double appText() =>
        MediaQuery.textScalerOf(tester.element(find.byType(AppBar).first))
            .scale(10);

    Future<void> pressCtrl(
      LogicalKeyboardKey key, {
      bool shift = false,
      PhysicalKeyboardKey? physical,
      String? platform,
    }) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key, physicalKey: physical, platform: platform);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await pressCtrl(LogicalKeyboardKey.equal);
    await pressCtrl(LogicalKeyboardKey.equal);
    expect(scaled(), closeTo(base * 1.2, 0.01));
    expect(appText(), closeTo(base, 0.01), reason: 'app text stays');
    expect(find.text('Document text size'), findsOne, reason: 'toast');
    expect(find.text('120 %'), findsOne);
    expect(
      find.textContaining('=', findRichText: true),
      findsNothing,
      reason: 'nothing typed',
    );

    await pressCtrl(LogicalKeyboardKey.minus);
    expect(scaled(), closeTo(base * 1.1, 0.01));

    await pressCtrl(LogicalKeyboardKey.digit0);
    expect(scaled(), closeTo(base, 0.01));

    // + with Shift on US layouts, its own key on German ones, the numpad.
    await pressCtrl(LogicalKeyboardKey.equal, shift: true);
    // A German layout's + key; Linux key codes in tests know none.
    Future<void> pressPlus({bool shift = false}) => pressCtrl(
      LogicalKeyboardKey.add,
      shift: shift,
      physical: PhysicalKeyboardKey.bracketRight,
      platform: 'android',
    );
    await pressPlus();
    await pressPlus(shift: true);
    await pressCtrl(LogicalKeyboardKey.numpadAdd);
    expect(scaled(), closeTo(base * 1.4, 0.01));

    // The home screen's cards show the same zoom, and zoom by the same keys.
    await tester.pageBack();
    await tester.waitForNoteClosed();
    double home() => MediaQuery.textScalerOf(
      tester.element(
        find.descendant(
          of: find.byType(DocumentCard),
          matching: find.text('Todo'),
        ),
      ),
    ).scale(10);
    expect(home(), closeTo(base * 1.4, 0.01));
    await pressCtrl(LogicalKeyboardKey.minus);
    expect(home(), closeTo(base * 1.3, 0.01));
  });

  testApp('starts at the saved zooms, documents and the app each at its own', (
    tester,
  ) async {
    app.write('todo.md', '# Todo\n- [ ] Call\n');
    await app.useTextZoom(TextZoomTarget.documents, TextZoom.closestTo(150));
    await app.useTextZoom(TextZoomTarget.app, TextZoom.closestTo(130));
    await app.launch(tester);

    double scaled(Finder text) =>
        MediaQuery.textScalerOf(tester.element(text)).scale(10);
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Folders'),
    );

    // The first frame already: nothing jumps once the settings load.
    expect(scaled(title), closeTo(13, 0.01));

    await tester.waitFor(find.text('Add folder'));
    await tester.addPickedFolder();
    await tester.waitFor(find.text('Todo'));
    expect(
      scaled(
        find.descendant(
          of: find.byType(DocumentCard),
          matching: find.text('Todo'),
        ),
      ),
      closeTo(15, 0.01),
    );
    expect(scaled(title), closeTo(13, 0.01));
  });
}
