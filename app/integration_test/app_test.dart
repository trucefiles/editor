import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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

  testWidgets('reopens a note in the view it was left in', (tester) async {
    app.file('todo.md').writeAsStringSync('# Todo\n- [ ] Call Bob\n');
    await addFolder(tester);
    await openNote(tester, 'Todo');
    expect(find.byType(Checkbox), findsOneWidget);

    await tester.tapAndSettle(find.byTooltip('View: List'));
    await tester.tapAndSettle(find.text('Text'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openNote(tester, 'Todo');

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byTooltip('View: Text'), findsOneWidget);
  });

  testWidgets('renders a note as Markdown', (tester) async {
    app.file('read.md').writeAsStringSync('# Read me\n\nSome **bold** text.\n');
    await addFolder(tester);
    await openNote(tester, 'Read me');

    await tester.tapAndSettle(find.byTooltip('View: Text'));
    await tester.tapAndSettle(find.text('Rendered'));

    expect(find.byType(TextField), findsNothing);
    expect(
      find.textContaining('Some bold text.', findRichText: true),
      findsOne,
    );
  });
}
