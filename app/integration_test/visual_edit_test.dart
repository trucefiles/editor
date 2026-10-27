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

  testApp('marks never show, in the clicked line either', (tester) async {
    await tester.openVisual(
      app,
      'Title',
      '# Title\n**bold** one\n\nplain *it*\n',
    );

    await tester.clickLine('bold one', 2);

    expect(tester.showsLine('bold one'), isTrue);
    expect(tester.showsLine('**bold** one'), isFalse);
    expect(tester.showsLine('plain it'), isTrue);
  });

  testApp('a new document shows it is not saved once typed in', (tester) async {
    await tester.addFolder(app);
    await tester.tapAndSettle(find.byTooltip('New document'));
    expect(find.byTooltip('Saved in the folder'), findsNothing);

    await tester.typeLines('x');

    expect(find.byTooltip('Saved in the folder'), findsNothing);
    expect(
      find.byTooltip('Editing…').evaluate().isNotEmpty ||
          find.byTooltip(savedOnDevice).evaluate().isNotEmpty,
      isTrue,
    );
  });

  testApp('list buttons turn lines into a list, change it and undo it', (
    tester,
  ) async {
    await tester.openVisual(app, 'Shop', '# Shop\nmilk\n\neggs\n');
    await tester.clickLine('milk', 0);
    await tester.pressShiftDownArrow();

    await tester.pressTool('Checklist (Ctrl+Shift+9)');
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.pressTool('Bulleted list (Ctrl+Shift+8)');
    expect(find.byType(Checkbox), findsNothing);
    await tester.pressTool('Numbered list (Ctrl+Shift+7)');

    await tester.leaveExpecting(app, '# Shop\n\n1. milk\n2. eggs\n');
  });

  testApp('Checklist twice gives the line back as it was', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\nmilk\n');
    await tester.clickLine('milk', 4);

    await tester.pressTool('Checklist (Ctrl+Shift+9)');
    await tester.pressTool('Checklist (Ctrl+Shift+9)');
    await tester.typeImeText('s');

    await tester.leaveExpecting(app, '# Shop\nmilks\n');
  });

  testApp('a list button on a heading makes it an item', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\nmilk\n');
    await tester.clickLine('Shop', 4);

    await tester.pressTool('Checklist (Ctrl+Shift+9)');
    await tester.typeImeText('!');

    await tester.leaveExpecting(app, '- [ ] # Shop!\n\nmilk\n');
  });

  testApp('Add item adds an item of the list kind', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- milk\n');

    await tester.tapAndSettle(find.text('Add item'));
    await tester.typeImeText('eggs');

    await tester.leaveExpecting(app, '# Shop\n- eggs\n- milk\n');
  });

  testApp('each list has its own Add item', (tester) async {
    await tester.openVisual(app, 'Two', '# Two\n- [ ] a\n\nText\n\n1. b\n');

    expect(find.text('Add item'), findsNWidgets(2));
  });

  testApp('drags an item below another', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');
    final rows =
        tester.pointIn(tester.lineNode('eggs'), 0) -
        tester.pointIn(tester.lineNode('milk'), 0);

    await tester.dragItem('milk', rows * 1.4);

    await tester.leaveExpecting(app, '# Shop\n- [ ] eggs\n- [ ] milk\n');
  });

  testApp('drags an item sideways to indent it, and back', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');

    await tester.dragItem('eggs', const Offset(40, 0));
    expect(tester.showsLine('eggs'), isTrue);
    await tester.pageBack();
    await tester.waitForFile(
      app.file('document.md'),
      '# Shop\n- [ ] milk\n  - [ ] eggs\n',
    );
    await tester.waitForNoteClosed();
    await tester.openNote('Shop');

    await tester.dragItem('eggs', const Offset(-40, 0));

    await tester.leaveExpecting(app, '# Shop\n- [ ] milk\n- [ ] eggs\n');
  });

  testApp('swiping an item right by touch indents it', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');
    final start = tester.pointIn(tester.lineNode('eggs'), 1);

    final finger = await tester.startGesture(start);
    for (var i = 0; i < 6; i++) {
      await finger.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();

    await tester.leaveExpecting(app, '# Shop\n- [ ] milk\n  - [ ] eggs\n');
  });

  testApp('checking an item shows it under Done, unchecking brings it back', (
    tester,
  ) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');
    await tester.chooseCheckedItems('Show at end');

    await tester.tapAndSettle(find.byType(Checkbox).first);
    await tester.waitFor(find.text('Done (1)'));
    await tester.tapAndSettle(find.byType(Checkbox).last);
    await tester.waitUntil(() => find.text('Done (1)').evaluate().isEmpty);

    await tester.leaveExpecting(app, '# Shop\n- [ ] milk\n- [ ] eggs\n');
  });

  testApp('Enter splits an item, Backspace joins it back', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milkshake\n');
    await tester.clickLine('milkshake', 4);

    await tester.pressEnter();
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.pressBackspace();
    await tester.pumpAndSettle();

    await tester.leaveExpecting(app, '# Shop\n- [ ] milkshake\n');
  });

  testApp('Enter after a numbered item numbers the next', (tester) async {
    await tester.openVisual(app, 'Steps', '# Steps\n1. one\n');
    await tester.clickLine('one', 3);

    await tester.pressEnter();
    await tester.typeImeText('two');

    await tester.leaveExpecting(app, '# Steps\n1. one\n2. two\n');
  });

  testApp('select all and type replaces the whole document, in its first '
      'block', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n> quote\n');
    await tester.clickLine('milk', 1);

    await tester.pressCtlA();
    await tester.pressBackspace();
    await tester.typeImeText('fresh');

    await tester.leaveExpecting(app, '# fresh\n');
  });

  testApp('deleting an item with its button can be undone', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');
    await tester.clickLine('milk', 1);

    await tester.tapAndSettle(find.byTooltip('Delete item').hitTestable());
    expect(find.byType(Checkbox), findsOneWidget);
    await tester.tapAndSettle(find.text('Undo'));

    await tester.leaveExpecting(app, '# Shop\n- [ ] milk\n- [ ] eggs\n');
  });

  testApp('typing in a quote keeps it a quote', (tester) async {
    await tester.openVisual(app, 'Quote', '# Quote\n> said\n');
    await tester.clickLine('said', 4);
    await tester.pressEnd();

    await tester.typeImeText(' so');
    await tester.clickLine('Quote', 1);

    expect(tester.showsLine('said so'), isTrue);
    await tester.leaveExpecting(app, '# Quote\n> said so\n');
  });

  testApp('Esc in a list leaves the document with every edit saved', (
    tester,
  ) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n');
    await tester.clickLine('milk', 4);
    await tester.typeImeText('y');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.waitForNoteClosed();

    await tester.waitForFile(app.file('document.md'), '# Shop\n- [ ] milky\n');
  });

  testApp('typed marks stay text', (tester) async {
    await tester.openVisual(app, 'Document', '# Document\nbuy milk\n');
    await tester.clickLine('buy milk', 8);

    await tester.typeImeText(' **now**');
    await tester.clickLine('Document', 2);
    expect(tester.showsLine('buy milk **now**'), isTrue);

    await tester.leaveExpecting(app, '# Document\nbuy milk \\*\\*now\\*\\*\n');
  });

  testApp('Backspace at the start of an item takes its box, then joins it '
      'to the one above', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n- [ ] shake\n');
    await tester.clickLine('shake', 1);
    await tester.pressLeftArrow();

    await tester.pressBackspace();
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsOneWidget);
    await tester.pressBackspace();
    await tester.typeImeText(' ');

    await tester.leaveExpecting(app, '# Shop\n- [ ] milk shake\n');
  });

  testApp('a change from elsewhere keeps the edited line editable', (
    tester,
  ) async {
    await app.useRefresh(RefreshMode.manual);
    await tester.openVisual(app, 'Plan', '# Plan\n**a** first\n\nsecond\n');
    await tester.clickLine('a first', 7);

    app.write('document.md', '# Plan\n**a** first\n\nsecond\n\nthird\n');
    await tester.tapAndSettle(find.byTooltip('Refresh'));
    await tester.waitFor(find.text('third', findRichText: true));
    expect(tester.showsLine('a first'), isTrue);
    await tester.typeImeText('!');

    await tester.leaveExpecting(
      app,
      '# Plan\n**a** first!\n\nsecond\n\nthird\n',
    );
  });
}
