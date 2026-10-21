import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor/notes/note_colors.dart';
import 'package:truce_editor/notes/ui/note_editor_screen.dart';

import 'app_steps.dart';
import 'editor_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of what users do off the happy path, in the real app
/// on the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/edge_cases_test.dart
/// -d linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  testApp('a new note titled like another gets a numbered file', (
    tester,
  ) async {
    app.write('Groceries.md', 'Groceries\nold\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Groceries'));

    await tester.typeNewNote('Groceries\nnew\n');
    await tester.pageBack();
    await tester.waitForNoteClosed();

    await tester.waitForFile(app.file('Groceries 2.md'), 'Groceries\nnew\n');
    expect(app.file('Groceries.md').readAsStringSync(), 'Groceries\nold\n');
  });

  testApp('a slash in the first line never makes a subfolder', (tester) async {
    await tester.addFolder(app);

    await tester.typeNewNote('# Mon/Tue: plan?\nx\n');
    await tester.pageBack();

    await tester.waitForNoteClosed();
    await tester.waitForFile(
      app.file('Mon Tue plan.md'),
      '# Mon/Tue: plan?\nx\n',
    );
    expect(app.namesIn(), ['Mon Tue plan.md']);
  });

  testApp('typing a new note and deleting it all leaves no file', (
    tester,
  ) async {
    await tester.addFolder(app);
    await tester.typeNewNote('Oops');
    await tester.pressCtlA();
    await tester.pressBackspace();
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.waitForNoteClosed();
    await tester.runFor(const Duration(seconds: 2));

    expect(app.topFiles, isEmpty);
  });

  testApp('renaming onto a taken name keeps the other note', (tester) async {
    app.write('plan.md', '# Plan\n');
    app.write('Ideas.md', '# Ideas\n');
    await tester.addFolder(app);
    await tester.openNote('Plan');

    await tester.placeNote(name: 'Ideas');
    await tester.runFor(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.waitForNoteClosed();

    expect(app.file('Ideas.md').readAsStringSync(), '# Ideas\n');
    expect(app.topFiles, hasLength(2));
  });

  testApp('opening and leaving a note without edits leaves its file alone', (
    tester,
  ) async {
    app.write('plan.md', '# Plan\r\n- [ ] a\r\n');
    final modified = app.file('plan.md').lastModifiedSync();
    await tester.addFolder(app);

    for (final mode in ['Visual edit', 'Markdown edit', 'Read']) {
      await tester.openNote('Plan');
      await tester.chooseMode(mode);
      await tester.pageBack();
      await tester.waitForNoteClosed();
    }
    await tester.runFor(const Duration(seconds: 3));

    expect(app.file('plan.md').readAsStringSync(), '# Plan\r\n- [ ] a\r\n');
    expect(app.file('plan.md').lastModifiedSync(), modified);
  });

  testApp('typing in a CRLF note keeps its line breaks', (tester) async {
    await tester.openVisual(
      app,
      'Shop',
      '# Shop\r\n- [ ] milk\r\n- [ ] eggs\r\n',
    );
    await tester.clickLine('milk', 4);

    await tester.typeImeText('y');
    await tester.pressEnter();
    await tester.typeImeText('tea');

    await tester.leaveExpecting(
      app,
      '# Shop\r\n- [ ] milky\r\n- [ ] tea\r\n- [ ] eggs\r\n',
    );
  });

  testApp('Enter on an empty item ends the list', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n');
    await tester.clickLine('milk', 4);

    await tester.pressEnter();
    await tester.pressEnter();
    await tester.typeImeText('after');

    await tester.leaveExpecting(app, '# Shop\n- [ ] milk\n\nafter\n');
  });

  testApp('Tab indents an item, Shift+Tab brings it back', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n- [ ] eggs\n');
    await tester.clickLine('eggs', 1);

    await tester.pressTab();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.pressTab();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    await tester.pressTab();
    await tester.pumpAndSettle();

    await tester.leaveExpecting(app, '# Shop\n- [ ] milk\n  - [ ] eggs\n');
  });

  testApp('Shift+Enter breaks the line inside an item', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n');
    await tester.clickLine('milk', 4);

    await tester.pressShiftEnter();
    await tester.typeImeText('oat');

    await tester.leaveExpecting(app, '# Shop\n- [ ] milk\\\n      oat\n');
  });

  testApp('a selection across items deletes and joins them', (tester) async {
    await tester.openVisual(
      app,
      'Shop',
      '# Shop\n- [ ] milk\n- [ ] eggs\n- [ ] tea\n',
    );
    await tester.clickLine('milk', 2);
    await tester.pressShiftDownArrow();
    await tester.pumpAndSettle();

    await tester.pressBackspace();
    await tester.pumpAndSettle();

    await tester.leaveExpecting(app, '# Shop\n- [ ] migs\n- [ ] tea\n');
  });

  testApp('pasting lines into an item adds them as items', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n');
    await tester.clickLine('milk', 4);
    await Clipboard.setData(const ClipboardData(text: 'eggs\ntea'));

    await tester.pressEnter();
    await tester.pressCtlV();
    await tester.pumpAndSettle();

    await tester.leaveExpecting(
      app,
      '# Shop\n- [ ] milk\n- [ ] eggs\n- [ ] tea\n',
    );
  });

  testApp('typing "- " at a line start makes an item', (tester) async {
    await tester.openVisual(app, 'Note', '# Note\ntext\n');
    await tester.clickLine('text', 4);

    await tester.pressEnter();
    await tester.typeImeText('- [ ] milk');

    await tester.leaveExpecting(app, '# Note\ntext\n- [ ] milk\n');
  });

  testApp('switching modes while typing keeps every edit', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n');
    await tester.clickLine('milk', 4);
    await tester.typeImeText('y');

    await tester.chooseMode('Markdown edit');
    await tester.tapAndSettle(find.byType(SuperEditor));
    await tester.pressCtrlEnd(tester);
    await tester.typeImeText('end');
    await tester.chooseMode('Read');
    await tester.chooseMode('Visual edit');

    await tester.leaveExpecting(app, '# Shop\n- [ ] milky\nend');
  });

  testApp('an empty file opens and takes text', (tester) async {
    app.write('blank.md', '');
    await tester.addFolder(app);
    await tester.openNote('blank');

    await tester.typeOver('Now text');
    await tester.pageBack();

    await tester.waitForFile(app.file('blank.md'), 'Now text');
  });

  testApp('a note deleted elsewhere while open keeps the edits', (
    tester,
  ) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n');
    await tester.clickLine('milk', 4);
    await tester.typeImeText('y');

    app.file('note.md').deleteSync();
    await tester.tapAndSettle(find.byTooltip('Refresh'));
    await tester.runFor(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.runFor(const Duration(seconds: 2));

    final texts = [for (final file in app.topFiles) file.readAsStringSync()];
    expect(texts, contains('# Shop\n- [ ] milky\n'));
  });

  testApp('search finds a note, an unknown word finds none', (tester) async {
    app.write('plan.md', '# Plan\nbuy milk\n');
    app.write('ideas.md', '# Ideas\nfly\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));

    await tester.tapAndSettle(find.byTooltip('Search'));
    await tester.enterText(find.byType(TextField), 'MILK');
    await tester.pumpAndSettle();
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Ideas'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz*(');
    await tester.pumpAndSettle();
    expect(find.text('Plan'), findsNothing);
  });

  testApp('undo of a delete after the name was reused keeps both', (
    tester,
  ) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openNote('Plan');
    await tester.chooseInMenu('Delete note');
    await tester.waitFor(find.text('Undo'));

    app.write('plan.md', '# Plan\nother\n');
    await tester.tapAndSettle(find.text('Undo'));
    await tester.runFor(const Duration(seconds: 2));

    final texts = [for (final file in app.topFiles) file.readAsStringSync()];
    expect(texts, containsAll(['# Plan\nv1\n', '# Plan\nother\n']));
  });

  testApp('a note renamed elsewhere while open keeps the edits', (
    tester,
  ) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [ ] milk\n');
    await tester.clickLine('milk', 4);
    await tester.typeImeText('y');

    app.file('note.md').renameSync(app.file('shop.md').path);
    await tester.tapAndSettle(find.byTooltip('Refresh'));
    await tester.runFor(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.runFor(const Duration(seconds: 2));

    final texts = {
      for (final file in app.topFiles)
        file.uri.pathSegments.last: file.readAsStringSync(),
    };
    expect(texts['shop.md'], '# Shop\n- [ ] milk\n');
    expect(texts.values, contains('# Shop\n- [ ] milky\n'));
    expect(texts.keys, isNot(contains('note.md')));
  });

  testApp('a note that is not UTF-8 is never written', (tester) async {
    app.file('latin.md').writeAsBytesSync([
      0x23,
      0x20,
      0x43,
      0x61,
      0x66,
      0xE9,
      0x0A,
    ]);
    await tester.addFolder(app);
    await tester.runFor(const Duration(seconds: 1));
    final card = find.textContaining('latin');
    if (card.evaluate().isNotEmpty) {
      await tester.tapAndSettle(card.first);
      await tester.runFor(const Duration(seconds: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pageBack();
      await tester.runFor(const Duration(seconds: 2));
    }

    expect(app.file('latin.md').readAsBytesSync(), [
      0x23,
      0x20,
      0x43,
      0x61,
      0x66,
      0xE9,
      0x0A,
    ]);
  });

  testApp('a BOM stays at the start after an edit', (tester) async {
    await tester.openVisual(app, 'Shop', '﻿# Shop\n- [ ] milk\n');
    await tester.clickLine('milk', 4);
    await tester.typeImeText('y');
    await tester.pageBack();
    await tester.waitForNoteClosed();
    await tester.runFor(const Duration(seconds: 1));

    expect(
      app.file('note.md').readAsBytesSync(),
      utf8.encode('﻿# Shop\n- [ ] milky\n'),
    );
  });

  testApp('Backspace after an emoji removes all of it', (tester) async {
    await tester.openVisual(app, 'Note', '# Note\nok\n');
    await tester.clickLine('ok', 2);
    await tester.typeImeText(' 👍🏽');

    await tester.pressBackspace();
    await tester.pumpAndSettle();

    await tester.leaveExpecting(app, '# Note\nok \n');
  });

  testApp('deleting the middle numbered item leaves the other lines alone', (
    tester,
  ) async {
    await tester.openVisual(
      app,
      'Steps',
      '# Steps\n1. one\n2. two\n3. three\n',
    );
    await tester.clickLine('two', 1);

    await tester.tapAndSettle(find.byTooltip('Item actions').hitTestable());
    await tester.tapAndSettle(find.text('Delete'));
    await tester.pumpAndSettle();

    await tester.leaveExpecting(app, '# Steps\n1. one\n3. three\n');
  });

  testApp('adding the same folder twice keeps one', (tester) async {
    app.write('plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));

    await tester.tapAndSettle(find.byTooltip('Manage folders'));
    await tester.tapAndSettle(find.text('Add folder'));
    await tester.runFor(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Plan'), findsOneWidget);
  });

  testApp('a double tap on a card opens the note once', (tester) async {
    app.write('plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));

    await tester.tap(find.text('Plan'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('Plan').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(NoteEditorScreen), findsNothing);
  });

  testApp('a double tap on New note starts one note', (tester) async {
    await tester.addFolder(app);

    await tester.tap(find.byTooltip('New note'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byTooltip('New note'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.typeLines('Idea');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(NoteEditorScreen), findsNothing);
    await tester.waitForFile(app.file('Idea.md'), 'Idea');
  });

  testApp('a color stays on a note moved to a subfolder', (tester) async {
    app.write('plan.md', '# Plan\n');
    app.folder('done').createSync();
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));
    await tester.tap(
      find.text('Plan'),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.byTooltip('teal'));

    await tester.openNote('Plan');
    await tester.placeNote(subfolder: 'done');
    await tester.waitForFile(app.file('done/plan.md'), '# Plan\n');
    await tester.pageBack();
    await tester.waitForNoteClosed();
    await tester.openNote('Plan');

    final screen = find.byType(NoteEditorScreen);
    final scheme = Theme.of(tester.element(screen)).colorScheme;
    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: screen, matching: find.byType(Scaffold)),
    );
    expect(scaffold.backgroundColor, noteTint('teal', scheme));
  });

  testApp('moving onto a taken name in a subfolder keeps both', (tester) async {
    app.write('plan.md', '# Plan\nmine\n');
    app.write('done/plan.md', '# Older\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));

    await tester.openNote('Plan');
    await tester.placeNote(subfolder: 'done');
    await tester.runFor(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.waitForNoteClosed();

    final texts = [
      for (final file in [
        ...app.topFiles,
        ...app.folder('done').listSync().whereType<File>(),
      ])
        file.readAsStringSync(),
    ];
    expect(texts, containsAll(['# Plan\nmine\n', '# Older\n']));
  });

  testApp('a subfolder deleted while a new note waits is not made again', (
    tester,
  ) async {
    app.write('old.md', '# Old\n');
    app.folder('inbox').createSync();
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));
    await tester.typeNewNote('Idea\n');
    await tester.placeNote(subfolder: 'inbox');

    app.folder('inbox').deleteSync(recursive: true);
    await tester.typeLines('more');
    await tester.pageBack();
    await tester.waitForNoteClosed();
    await tester.runFor(const Duration(seconds: 1));

    expect(app.folder('inbox').existsSync(), isFalse);
    final texts = [for (final file in app.topFiles) file.readAsStringSync()];
    expect(texts, contains('Idea\nmore'));
  });

  testApp('a pin comes back with an undone delete', (tester) async {
    app.write('plan.md', '# Plan\n');
    app.write('ideas.md', '# Ideas\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));
    await tester.longPress(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.text('Pin'));
    await tester.waitFor(find.byTooltip('Pinned'));

    await tester.openNote('Plan');
    await tester.chooseInMenu('Delete note');
    await tester.waitFor(find.text('Undo'));
    await tester.tapAndSettle(find.text('Undo'));
    await tester.waitForFile(app.file('plan.md'), '# Plan\n');

    await tester.waitFor(find.byTooltip('Pinned'));
  });

  testApp('clearing checked items can be undone', (tester) async {
    await tester.openVisual(app, 'Shop', '# Shop\n- [x] milk\n- [ ] eggs\n');

    await tester.chooseInMenu('Clear checked items');
    expect(find.byType(Checkbox), findsOneWidget);
    await tester.tapAndSettle(find.text('Undo'));

    await tester.leaveExpecting(app, '# Shop\n- [x] milk\n- [ ] eggs\n');
  });

  testApp('the same title in two subfolders opens each note', (tester) async {
    app.write('a/plan.md', '# Plan\nin a\n');
    app.write('b/plan.md', '# Plan\nin b\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));
    expect(find.text('Plan'), findsNWidgets(2));

    await tester.tapAndSettle(find.text('Plan').last);
    await tester.typeOver('# Plan\nedited\n');
    await tester.pageBack();
    await tester.waitForNoteClosed();

    final texts = {
      app.file('a/plan.md').readAsStringSync(),
      app.file('b/plan.md').readAsStringSync(),
    };
    expect(texts, hasLength(2));
    expect(texts, contains('# Plan\nedited\n'));
  });
}
