import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_editor/super_editor.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of unreachable folders, conflicts and backups, in the
/// real app on the desktop, against a real folder.
///
/// Run on Linux with `flutter test
/// integration_test/reach_and_conflicts_test.dart -d linux` (in CI under
/// `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  /// Opens the document Plan in [tester], as text, with mine typed in and a
  /// change from elsewhere in its file.
  Future<void> clashInPlan(WidgetTester tester) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nmine\n');
    app.write('plan.md', '# Plan\nv2 from elsewhere\n');
  }

  testApp('a folder that is gone is retried, then no new document goes in', (
    tester,
  ) async {
    await tester.addFolder(app);
    await tester.waitFor(find.byTooltip('New document'));
    await tester.loseFolder(app.documents);

    await tester.tapAndSettle(find.byTooltip('New document'));

    await tester.waitFor(find.text('No folder can be reached right now.'));
    expect(app.documents.existsSync(), isFalse);
  });

  testApp('an open document is read-only while its folder is unreachable', (
    tester,
  ) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.chooseMode('Markdown edit');
    await tester.loseFolder(app.documents);

    await tester.waitFor(find.textContaining("Documents can't be reached."));
    expect(find.byType(SuperEditor), findsNothing);

    Directory('${app.documents.path}-away').renameSync(app.documents.path);
    await tester.tapAndSettle(find.text('Retry'));
    await tester.waitFor(find.byType(SuperEditor));
    expect(find.textContaining("can't be reached"), findsNothing);
  });

  testApp('back from a document whose folder just went away keeps the edits', (
    tester,
  ) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nmine\n');
    app.documents.renameSync('${app.documents.path}-away');

    await tester.pageBack();

    await tester.waitForNoteClosed(timeout: const Duration(seconds: 20));
    expect(find.text("Your edits can't be saved"), findsNothing);
  });

  testApp('a document moved to another folder goes by that folder\'s reach', (
    tester,
  ) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.addWorkFolder();
    await tester.openDocument('Plan');
    await tester.chooseMode('Markdown edit');
    await tester.placeNote(folder: 'Work');
    await tester.waitUntil(() => File('${app.work.path}/plan.md').existsSync());

    await tester.loseFolder(app.work);

    await tester.waitFor(find.textContaining("Work can't be reached."));
    expect(find.byType(SuperEditor), findsNothing);
    await tester.pageBack();
    await tester.waitForNoteClosed(timeout: const Duration(seconds: 20));
    expect(find.text("Your edits can't be saved"), findsNothing);
  });

  testApp('back keeps edits that clash as a conflict copy', (tester) async {
    await clashInPlan(tester);
    await tester.pageBack();

    await tester.waitUntil(() => app.conflictCopies().isNotEmpty);
    expect(app.conflictCopies().single.readAsStringSync(), '# Plan\nmine\n');
    expect(
      app.file('plan.md').readAsStringSync(),
      '# Plan\nv2 from elsewhere\n',
    );
    await tester.waitFor(find.byTooltip('New document'));
  });

  testApp('compares a change from elsewhere and keeps mine', (tester) async {
    await clashInPlan(tester);
    await tester.tapAndSettle(find.byTooltip('Refresh'));

    await tester.openCompare();
    // In both panes: as one version's line and as the other's.
    expect(find.textContaining('v2 from elsewhere'), findsNWidgets(2));
    await tester.keep(find.text('Keep this').last);

    await tester.waitForFile(app.file('plan.md'), '# Plan\nmine\n');
    await tester.waitUntil(() => find.text('Your edits').evaluate().isEmpty);
  });

  testApp('hiding the app keeps clashing edits here to compare, menus stay '
      'put', (tester) async {
    await clashInPlan(tester);
    await tester.tapAndSettle(find.byTooltip('Show menu'));

    tester.hideAndComeBack();

    await tester.waitFor(find.textContaining('changed on another device'));
    expect(find.text('Delete document'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.byType(SuperEditor), findsOneWidget);
    expect(
      app.file('plan.md').readAsStringSync(),
      '# Plan\nv2 from elsewhere\n',
    );
  });

  testApp('restores the version from before editing', (tester) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nbroken\n');
    await tester.pageBack();
    await tester.waitForFile(app.file('plan.md'), '# Plan\nbroken\n');
    await tester.waitForNoteClosed();

    await tester.chooseInMenu('Backups');
    await tester.waitFor(find.textContaining('Before editing'));
    await tester.tapAndSettle(find.textContaining('Before editing'));
    await tester.waitFor(find.text('Restore'));
    await tester.keep(find.text('Restore'));

    await tester.waitForFile(app.file('plan.md'), '# Plan\nv1\n');
    await tester.waitFor(find.text('Backup restored.'));
  });

  testApp('keeps clashing edits of a deep document as a conflict copy', (
    tester,
  ) async {
    app.write('a/b/c/plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nmine\n');
    app.write('a/b/c/plan.md', '# Plan\nv2 from elsewhere\n');
    await tester.pageBack();

    await tester.waitUntil(() => app.conflictCopies('a/b/c').isNotEmpty);
    expect(
      app.conflictCopies('a/b/c').single.readAsStringSync(),
      '# Plan\nmine\n',
    );
    expect(app.topFiles, isEmpty);
    await tester.waitFor(find.byTooltip('Sync conflict'));
  });

  testApp('resolves a conflict several levels deep', (tester) async {
    app.write('a/b/c/todo.md', '# Todo\nmine\n');
    app.write(
      'a/b/c/todo.sync-conflict-20261003-134809-ABCDEFG.md',
      '# Todo\nfirst\n',
    );
    await tester.addFolder(app);
    await tester.openDocument('Todo');

    await tester.openCompare();
    expect(find.text('Documents/a/b/c'), findsOne);
    await tester.keep(find.text('Keep this').last);

    await tester.waitFor(find.textContaining('Conflict resolved'));
    expect(app.namesIn('a/b/c'), ['todo.md']);
    expect(app.file('a/b/c/todo.md').readAsStringSync(), '# Todo\nfirst\n');
  });

  testApp('lists every conflict and resolves one from the list', (
    tester,
  ) async {
    app.write('todo.md', '# Todo\nmine\n');
    app.write('todo.sync-conflict-20261003-134809-ABCDEFG.md', '# Todo\nx\n');
    await tester.addFolder(app);

    await tester.waitFor(find.byTooltip('Conflicts'));
    await tester.tapAndSettle(find.byTooltip('Conflicts'));
    expect(find.text('1 other version'), findsOne);
    await tester.tapAndSettle(find.text('Todo'));
    await tester.keep(find.text('Keep this').last);

    await tester.waitFor(find.text('No sync conflicts.'));
    expect(app.file('todo.md').readAsStringSync(), '# Todo\nx\n');
  });

  testApp('resolves two conflict copies one by one', (tester) async {
    app.write('todo.md', '# Todo\nmine\n');
    app.write(
      'todo.sync-conflict-20261003-134809-ABCDEFG.md',
      '# Todo\nfirst\n',
    );
    app.write(
      'todo.sync-conflict-20261004-080000-ABCDEFG.md',
      '# Todo\nsecond\n',
    );
    await tester.addFolder(app);
    await tester.openDocument('Todo');

    await tester.openCompare();
    await tester.waitFor(find.text('2 other versions, oldest first'));
    await tester.keep(find.text('Keep this').first);
    await tester.waitFor(find.textContaining('second', findRichText: true));
    expect(find.text('2 other versions, oldest first'), findsNothing);

    await tester.keep(find.text('Keep this').first);

    await tester.waitFor(find.textContaining('Conflict resolved'));
    expect(app.namesIn(), ['todo.md']);
    expect(app.file('todo.md').readAsStringSync(), '# Todo\nmine\n');
  });
}
