import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of refreshing and of changes made outside the app, in
/// the real app on the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/refresh_test.dart -d
/// linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  final fromElsewhere = find.textContaining(
    'v2 from elsewhere',
    findRichText: true,
  );

  testApp('shows a change made by another app', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openNote('Plan');

    app.write('plan.md', '# Plan\nv2 from elsewhere\n');
    await tester.refocusApp();

    await tester.waitFor(fromElsewhere);
    expect(
      find.text('Updated with a change from another device or app'),
      findsOne,
    );
  });

  testApp('shows a change made before the note opened', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));

    app.write('plan.md', '# Plan\nv2 from elsewhere\n');
    await tester.tapAndSettle(find.text('Plan'));

    await tester.waitFor(fromElsewhere);
  });

  testApp('the refresh button shows new notes', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    await tester.addFolder(app);
    await tester.waitFor(find.byTooltip('New note'));

    app.write('new.md', '# New\n');
    await tester.tapAndSettle(find.byTooltip('Refresh'));

    await tester.waitFor(find.text('New'));
  });

  testApp('pulling the grid down shows new notes', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('old.md', '# Old\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Old'));

    app.write('new.md', '# New\n');
    await tester.fling(find.text('Old'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    await tester.waitFor(find.text('New'));
  });

  testApp('the refresh button in an open note shows a change', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openNote('Plan');

    app.write('plan.md', '# Plan\nv2 from elsewhere\n');
    await tester.tapAndSettle(find.byTooltip('Refresh'));

    await tester.waitFor(fromElsewhere);
  });

  testApp('shows new notes and changes live, without refreshing', (
    tester,
  ) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));

    app.write('deep/new.md', '# New\n');
    await tester.waitFor(find.text('New'));

    await tester.openNote('Plan');
    app.write('plan.md', '# Plan\nv2 from elsewhere\n');
    await tester.waitFor(fromElsewhere);
  });

  testApp('switches to manual refresh in the settings', (tester) async {
    await tester.addFolder(app);
    await tester.waitFor(find.byTooltip('New note'));

    await tester.chooseInMenu('Settings');
    await tester.tapAndSettle(find.text('Refresh'));
    await tester.tapAndSettle(find.text('Manual'));
    await tester.tapAndSettle(find.text('Save'));
    // The setting is saved, then the app rescans once for changes made
    // meanwhile; a file written before that is rightly found.
    await tester.waitFor(find.text('Manual'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.runFor(const Duration(seconds: 1));
    app.write('new.md', '# New\n');
    await tester.runFor(const Duration(seconds: 2));

    expect(find.text('New'), findsNothing);
  });

  testApp('never writes back a change shown in the open note', (tester) async {
    app.write('todo.md', '# Todo\n- [ ] milk\n');
    await tester.addFolder(app);
    await tester.openNote('Todo');
    final file = app.file('todo.md');
    final from = DateTime(2001);

    /// Changes the note elsewhere, waits until the open note shows it, and
    /// over a few rescans checks that the app leaves the file alone.
    Future<void> changeElsewhere(String text, Finder shown) async {
      file
        ..writeAsStringSync(text)
        ..setLastModifiedSync(from);
      await tester.refocusApp();
      await tester.waitFor(shown);
      for (var i = 0; i < 3; i++) {
        await tester.runFor(const Duration(seconds: 3));
        await tester.refocusApp();
      }
      expect(file.readAsStringSync(), text);
      expect(file.lastModifiedSync(), from);
    }

    // Visual edit, then Markdown edit.
    await changeElsewhere(
      '# Todo\n- [x] milk\n- [ ] eggs\n',
      find.text('eggs', findRichText: true),
    );
    await tester.chooseMode('Markdown edit');
    await changeElsewhere(
      '# Todo\n- [x] milk\n- [ ] eggs\n- [ ] tea\n',
      find.textContaining('tea', findRichText: true),
    );
  });
}
