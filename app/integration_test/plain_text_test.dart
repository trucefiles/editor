import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

import 'app_steps.dart';
import 'editor_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of plain text (`.txt`) documents, in the real app on
/// the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/plain_text_test.dart
/// -d linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  testApp('a text file shows as a card: its first line, then the rest', (
    tester,
  ) async {
    app.write('shopping.txt', 'Shopping\n\n# milk\n- [ ] eggs\n');
    await tester.addFolder(app);

    await tester.waitFor(find.text('Shopping'));
    expect(find.text('# milk\n- [ ] eggs', findRichText: true), findsOne);
  });

  testApp('edits a text file as written, with no modes; back saves it', (
    tester,
  ) async {
    app.write('shopping.txt', 'Shopping\r\n# milk\r\n');
    await tester.addFolder(app);
    await tester.openNote('Shopping');

    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton<EditMode>),
      findsNothing,
    );
    expect(tester.showsLine('# milk'), isTrue);
    await tester.clickLine('# milk', 6);
    await tester.typeImeText(' and eggs');

    await tester.pageBack();
    await tester.waitForFile(
      app.file('shopping.txt'),
      'Shopping\r\n# milk and eggs\r\n',
    );
  });

  testApp('Ctrl+Z and Ctrl+Y undo and redo typing', (tester) async {
    app.write('plan.txt', 'Plan\nab\n');
    await tester.addFolder(app);
    await tester.openNote('Plan');
    await tester.clickLine('ab', 2);
    await tester.typeImeText('cd');

    await tester.pressCtrl(LogicalKeyboardKey.keyZ);
    expect(tester.showsLine('ab'), isTrue);
    await tester.pressCtrl(LogicalKeyboardKey.keyY);
    expect(tester.showsLine('abcd'), isTrue);

    await tester.pageBack();
    await tester.waitForFile(app.file('plan.txt'), 'Plan\nabcd\n');
  });

  testApp('typing after a click away and back is a new undo step', (
    tester,
  ) async {
    app.write('list.txt', 'List\nmilk\n');
    await tester.addFolder(app);
    await tester.openNote('List');
    await tester.clickLine('milk', 4);
    await tester.typeImeText(' egg');
    await tester.clickLine('List', 0);
    await tester.clickLine('milk egg', 8);
    await tester.typeImeText('s');

    await tester.pressCtrl(LogicalKeyboardKey.keyZ);
    expect(tester.showsLine('milk egg'), isTrue);

    await tester.pageBack();
    await tester.waitForFile(app.file('list.txt'), 'List\nmilk egg\n');
  });

  testApp('compares a change from elsewhere and keeps mine', (tester) async {
    app.write('plan.txt', 'Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openNote('Plan');
    await tester.typeOver('Plan\nmine\n');
    app.write('plan.txt', 'Plan\nv2 from elsewhere\n');
    await tester.tapAndSettle(find.byTooltip('Refresh'));

    await tester.openCompare();
    expect(find.textContaining('v2 from elsewhere'), findsNWidgets(2));
    await tester.keep(find.text('Keep this').last);

    await tester.waitForFile(app.file('plan.txt'), 'Plan\nmine\n');
  });

  testApp('restores a backup into the open document', (tester) async {
    app.write('plan.txt', 'Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openNote('Plan');
    await tester.typeOver('Plan\nbroken\n');
    await tester.pageBack();
    await tester.waitForFile(app.file('plan.txt'), 'Plan\nbroken\n');
    await tester.waitForNoteClosed();
    await tester.waitFor(find.textContaining('broken', findRichText: true));
    await tester.openNote('Plan');

    await tester.chooseInMenu('Backups');
    await tester.waitFor(find.textContaining('Before editing'));
    await tester.tapAndSettle(find.textContaining('Before editing'));
    await tester.waitFor(find.text('Restore'));
    await tester.keep(find.text('Restore'));

    await tester.waitFor(find.text('Backup restored'));
    expect(find.byType(SuperEditor), findsOne);
    await tester.pageBack();
    await tester.waitForFile(app.file('plan.txt'), 'Plan\nv1\n');
  });
}
