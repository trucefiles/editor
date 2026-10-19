import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_editor/super_editor_test.dart';

import 'package:truce_editor/refresh/refresh_settings.dart';

import 'app_steps.dart';
import 'editor_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of Visual edit, in the real app on the desktop,
/// against a real folder: what shows while editing, the toolbar, list
/// items and their drag, and what lands in the file.
///
/// Run on Linux with `flutter test integration_test/visual_edit_test.dart
/// -d linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  /// Opens the note [title], written as [text], in Visual edit.
  Future<void> openVisual(
    WidgetTester tester,
    String title,
    String text,
  ) async {
    app.write('note.md', text);
    await tester.addFolder(app);
    await tester.openNote(title);
    if (find.byTooltip('Mode: Visual edit').evaluate().isEmpty) {
      await tester.chooseMode('Visual edit');
    }
  }

  /// Leaves the note and waits for its file to hold [text].
  Future<void> leaveExpecting(WidgetTester tester, String text) async {
    await tester.pageBack();
    await tester.waitForFile(app.file('note.md'), text);
  }

  testApp('the clicked line shows its marks, the others hide them', (
    tester,
  ) async {
    await openVisual(tester, 'Title', '# Title\n**bold** one\nplain *it*\n');
    expect(tester.showsLine('bold one'), isTrue);

    await tester.clickLine('**bold** one', 2);
    expect(tester.showsLine('**bold** one'), isTrue);
    expect(tester.showsLine('plain it'), isTrue);

    await tester.clickLine('plain *it*', 2);
    expect(tester.showsLine('plain *it*'), isTrue);
    expect(tester.showsLine('bold one'), isTrue);
  });

  testApp('the marks follow the caret moved by arrow keys', (tester) async {
    await openVisual(tester, 'Title', '# Title\n**bold** one\nplain *it*\n');
    await tester.clickLine('**bold** one', 2);

    await tester.pressDownArrow();
    await tester.pumpAndSettle();
    expect(tester.showsLine('plain *it*'), isTrue);
    expect(tester.showsLine('bold one'), isTrue);

    await tester.pressUpArrow();
    await tester.pumpAndSettle();
    expect(tester.showsLine('**bold** one'), isTrue);
  });

  testApp('the marks still follow the caret after an edit is saved', (
    tester,
  ) async {
    await openVisual(tester, 'Title', '# Title\n**bold** one\nplain *it*\n');
    await tester.clickLine('plain *it*', 10);
    await tester.typeImeText('!');
    await tester.waitFor(find.byTooltip(savedOnDevice));
    await tester.tap(find.byTooltip(savedOnDevice));
    await tester.waitForFile(
      app.file('note.md'),
      '# Title\n**bold** one\nplain *it*!\n',
    );

    await tester.clickLine('**bold** one', 2);

    expect(tester.showsLine('**bold** one'), isTrue);
    expect(tester.showsLine('plain it!'), isTrue);
  });

  testApp('a new note shows it is being edited, not saved', (tester) async {
    await tester.addFolder(app);
    await tester.tapAndSettle(find.byTooltip('New note'));

    expect(find.byTooltip('Editing…'), findsOneWidget);
    expect(find.byTooltip('Saved in the folder'), findsNothing);
  });

  testApp('list buttons turn lines into a list, change it and undo it', (
    tester,
  ) async {
    await openVisual(tester, 'Shop', '# Shop\nmilk\neggs\n');
    await tester.clickLine('milk', 0);
    await tester.pressShiftDownArrow();

    await tester.pressTool('Checklist');
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.pressTool('Bulleted list');
    expect(find.byType(Checkbox), findsNothing);
    await tester.pressTool('Numbered list');

    await leaveExpecting(tester, '# Shop\n1. milk\n1. eggs\n');
  });

  testApp('a list button twice gives back the text', (tester) async {
    await openVisual(tester, 'Shop', '# Shop\nmilk\n');
    await tester.clickLine('milk', 4);

    await tester.pressTool('Checklist');
    await tester.pressTool('Checklist');
    await tester.typeImeText('s');

    await leaveExpecting(tester, '# Shop\nmilks\n');
  });

  testApp('a list button on a heading starts a list below it', (tester) async {
    await openVisual(tester, 'Shop', '# Shop\nmilk\n');
    await tester.clickLine('# Shop', 2);

    await tester.pressTool('Checklist');
    await tester.typeImeText('bread');

    await leaveExpecting(tester, '# Shop\n- [ ] bread\nmilk\n');
  });

  testApp('Add item adds an item of the list kind', (tester) async {
    await openVisual(tester, 'Shop', '# Shop\n- milk\n');

    await tester.tapAndSettle(find.text('Add item'));
    await tester.typeImeText('eggs');

    await leaveExpecting(tester, '# Shop\n- eggs\n- milk\n');
  });

  testApp('each list has its own Add item', (tester) async {
    await openVisual(tester, 'Two', '# Two\n- [ ] a\n\nText\n\n1. b\n');

    expect(find.text('Add item'), findsNWidgets(2));
  });

  testApp('drags an item below another', (tester) async {
    await openVisual(tester, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');
    final rows =
        tester.pointIn(tester.lineNode('eggs'), 0) -
        tester.pointIn(tester.lineNode('milk'), 0);

    await tester.dragItem('milk', rows * 1.4);

    await leaveExpecting(tester, '# Shop\n- [ ] eggs\n- [ ] milk\n');
  });

  testApp('drags an item sideways to indent it, and back', (tester) async {
    await openVisual(tester, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');

    await tester.dragItem('eggs', const Offset(40, 0));
    expect(tester.showsLine('eggs'), isTrue);
    await tester.pageBack();
    await tester.waitForFile(
      app.file('note.md'),
      '# Shop\n- [ ] milk\n  - [ ] eggs\n',
    );
    await tester.waitForNoteClosed();
    await tester.openNote('Shop');

    await tester.dragItem('eggs', const Offset(-40, 0));

    await leaveExpecting(tester, '# Shop\n- [ ] milk\n- [ ] eggs\n');
  });

  testApp('swiping an item right by touch indents it', (tester) async {
    await openVisual(tester, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');
    final start = tester.pointIn(tester.lineNode('eggs'), 1);

    final finger = await tester.startGesture(start);
    for (var i = 0; i < 6; i++) {
      await finger.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();

    await leaveExpecting(tester, '# Shop\n- [ ] milk\n  - [ ] eggs\n');
  });

  testApp('checking an item shows it under Done, unchecking brings it back', (
    tester,
  ) async {
    await openVisual(tester, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');

    await tester.tapAndSettle(find.byType(Checkbox).first);
    expect(find.text('Done (1)'), findsOneWidget);
    await tester.tapAndSettle(find.byType(Checkbox).last);
    expect(find.text('Done (1)'), findsNothing);

    await leaveExpecting(tester, '# Shop\n- [ ] milk\n- [ ] eggs\n');
  });

  testApp('Enter splits an item, Backspace joins it back', (tester) async {
    await openVisual(tester, 'Shop', '# Shop\n- [ ] milkshake\n');
    await tester.clickLine('milkshake', 4);

    await tester.pressEnter();
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.pressBackspace();
    await tester.pumpAndSettle();

    await leaveExpecting(tester, '# Shop\n- [ ] milkshake\n');
  });

  testApp('Enter after a numbered item numbers the next', (tester) async {
    await openVisual(tester, 'Steps', '# Steps\n1. one\n');
    await tester.clickLine('one', 3);

    await tester.pressEnter();
    await tester.typeImeText('two');

    await leaveExpecting(tester, '# Steps\n1. one\n2. two\n');
  });

  testApp('select all and type replaces the whole note', (tester) async {
    await openVisual(tester, 'Shop', '# Shop\n- [ ] milk\n> quote\n');
    await tester.clickLine('milk', 1);

    await tester.pressCtlA();
    await tester.pressBackspace();
    await tester.typeImeText('fresh');

    await leaveExpecting(tester, 'fresh');
  });

  testApp('deleting an item from its menu can be undone', (tester) async {
    await openVisual(tester, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');
    await tester.clickLine('milk', 1);

    await tester.tapAndSettle(find.byTooltip('Item actions').hitTestable());
    await tester.tapAndSettle(find.text('Delete'));
    expect(find.byType(Checkbox), findsOneWidget);
    await tester.tapAndSettle(find.text('Undo'));

    await leaveExpecting(tester, '# Shop\n- [ ] milk\n- [ ] eggs\n');
  });

  testApp('typing in a quote keeps it a quote', (tester) async {
    await openVisual(tester, 'Quote', '# Quote\n> said\n');
    await tester.clickLine('> said', 4);
    await tester.pressEnd();

    await tester.typeImeText(' so');
    await tester.clickLine('# Quote', 1);

    expect(tester.showsLine('said so'), isTrue);
    await leaveExpecting(tester, '# Quote\n> said so\n');
  });

  testApp('Esc in a list leaves the note with every edit saved', (
    tester,
  ) async {
    await openVisual(tester, 'Shop', '# Shop\n- [ ] milk\n');
    await tester.clickLine('milk', 4);
    await tester.typeImeText('y');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.waitForNoteClosed();

    await tester.waitForFile(app.file('note.md'), '# Shop\n- [ ] milky\n');
  });

  testApp('typed marks show while on the line, format once left', (
    tester,
  ) async {
    await openVisual(tester, 'Note', '# Note\nbuy milk\n');
    await tester.clickLine('buy milk', 8);

    await tester.typeImeText(' **now**');
    expect(tester.showsLine('buy milk **now**'), isTrue);
    await tester.clickLine('# Note', 2);
    expect(tester.showsLine('buy milk now'), isTrue);

    await leaveExpecting(tester, '# Note\nbuy milk **now**\n');
  });

  testApp('Backspace at the start of an item joins it to the one above', (
    tester,
  ) async {
    await openVisual(tester, 'Shop', '# Shop\n- [ ] milk\n- [ ] shake\n');
    await tester.clickLine('shake', 1);
    await tester.pressLeftArrow();

    await tester.pressBackspace();
    await tester.typeImeText(' ');

    await leaveExpecting(tester, '# Shop\n- [ ] milk shake\n');
  });

  testApp('a change from elsewhere keeps the edited line editable', (
    tester,
  ) async {
    await app.useRefresh(RefreshMode.manual);
    await openVisual(tester, 'Plan', '# Plan\n**a** first\nsecond\n');
    await tester.clickLine('**a** first', 11);

    app.write('note.md', '# Plan\n**a** first\nsecond\nthird\n');
    await tester.tapAndSettle(find.byTooltip('Refresh'));
    await tester.waitFor(find.text('third', findRichText: true));
    expect(tester.showsLine('**a** first'), isTrue);
    await tester.typeImeText('!');

    await leaveExpecting(tester, '# Plan\n**a** first!\nsecond\nthird\n');
  });
}
