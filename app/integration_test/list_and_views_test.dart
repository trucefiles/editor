import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of checklists and a note's views, in the real app on
/// the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/list_and_views_test.dart
/// -d linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  testWidgets('checks a checklist item and saves it', (tester) async {
    app.write('todo.md', '# Todo\n- [ ] Call Bob\n');
    await tester.addFolder(app);
    await tester.openNote('Todo');

    await tester.tapAndSettle(find.byType(Checkbox));
    await tester.pageBack();

    await tester.waitForFile(app.file('todo.md'), '# Todo\n- [x] Call Bob\n');
  });

  testWidgets('edits a note several levels deep', (tester) async {
    app.write('a/b/c/todo.md', '# Deep\n- [ ] Call Bob\n');
    app.write('todo.md', '# Root\n');
    await tester.addFolder(app);

    await tester.waitFor(find.text('Notes/a/b/c'));
    await tester.openNote('Deep');
    expect(find.text('Notes/a/b/c/todo.md'), findsOne);
    await tester.tapAndSettle(find.byType(Checkbox));
    await tester.pageBack();

    await tester.waitForFile(
      app.file('a/b/c/todo.md'),
      '# Deep\n- [x] Call Bob\n',
    );
    expect(app.file('todo.md').readAsStringSync(), '# Root\n');
  });

  testWidgets('an undo in a checklist goes away with the note', (tester) async {
    app.write('list.md', '# List\n- [ ] a\n- [x] b\n');
    await tester.addFolder(app);
    await tester.openNote('List');
    await tester.tapAndSettle(find.text('Clear done'));
    expect(find.text('Undo'), findsOneWidget);

    await tester.pageBack();

    await tester.waitForNoteClosed();
    expect(find.text('Undo'), findsNothing);
    await tester.waitForFile(app.file('list.md'), '# List\n- [ ] a\n');
  });

  testWidgets('a note keeps its Done section choice, on this device only', (
    tester,
  ) async {
    app.write('list.md', '# List\n- [ ] a\n- [x] b\n');
    await tester.addFolder(app);
    await tester.openNote('List');
    expect(find.text('1 done'), findsOneWidget);

    await tester.chooseCheckedItems('In place');
    await tester.waitUntil(() => find.text('1 done').evaluate().isEmpty);
    await tester.pageBack();
    await tester.waitForNoteClosed();
    await tester.openNote('List');

    expect(find.text('1 done'), findsNothing);
    expect(app.folder('.truce').existsSync(), isFalse);
  });

  testWidgets('with move to end, checking moves the item in the file', (
    tester,
  ) async {
    app.write('list.md', '# List\n- [x] a\n- [ ] b\n- [ ] c\n');
    await tester.addFolder(app);
    await tester.openNote('List');

    await tester.chooseCheckedItems('Move to end');
    await tester.tapAndSettle(find.byType(Checkbox).first);
    await tester.pageBack();

    await tester.waitForFile(
      app.file('list.md'),
      '# List\n- [ ] c\n- [x] a\n- [x] b\n',
    );
  });

  testWidgets('reopens a note in the view it was left in', (tester) async {
    app.write('todo.md', '# Todo\n- [ ] Call Bob\n');
    await tester.addFolder(app);
    await tester.openNote('Todo');
    expect(find.byType(Checkbox), findsOneWidget);

    await tester.showListSource();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.openNote('Todo');

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byTooltip('View: Source'), findsOneWidget);
  });

  testWidgets('first shows a note that is no list rendered', (tester) async {
    app.write('read.md', '# Read me\n\nSome **bold** text.\n');
    await tester.addFolder(app);

    await tester.openNote('Read me');

    expect(find.byTooltip('View: Rendered'), findsOne);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.textContaining('Some bold text.', findRichText: true),
      findsOne,
    );
  });

  testWidgets('Ctrl+1, 2 and 3 switch between Source, List and Rendered', (
    tester,
  ) async {
    app.write('todo.md', '# Todo\n- [ ] Call\n');
    await tester.addFolder(app);
    await tester.openNote('Todo');

    Future<void> pressCtrl(LogicalKeyboardKey digit) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(digit);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await pressCtrl(LogicalKeyboardKey.digit3);
    expect(find.byTooltip('View: Rendered'), findsOne);
    await pressCtrl(LogicalKeyboardKey.digit1);
    expect(find.byTooltip('View: Source'), findsOne);
    await pressCtrl(LogicalKeyboardKey.digit2);
    expect(find.byTooltip('View: List'), findsOne);
  });
}
