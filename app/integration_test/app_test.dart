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
}
