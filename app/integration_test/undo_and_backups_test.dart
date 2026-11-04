import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'app_steps.dart';
import 'editor_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of undo and redo and of a file's own backups, in
/// the real app on the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/undo_and_backups_test.dart
/// -d linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  /// Opens Plan, edits it to `broken` and leaves, so a backup from before
  /// editing is kept; then opens it again.
  Future<void> planWithBackup(WidgetTester tester) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openFile('Plan');
    await tester.typeOver('# Plan\nbroken\n');
    await tester.pageBack();
    await tester.waitForFile(app.file('plan.md'), '# Plan\nbroken\n');
    await tester.waitForNoteClosed();
    // The grid shows the edit, so the file opens as written.
    await tester.waitFor(find.textContaining('broken', findRichText: true));
    await tester.openFile('Plan');
  }

  testApp('Ctrl+Z, Ctrl+Y and the buttons undo and redo typing', (
    tester,
  ) async {
    await tester.openVisual(app, 'Plan', '# Plan\n\nab\n');
    await tester.clickLine('ab', 2);
    await tester.typeImeText('cd');

    await tester.pressCtrl(LogicalKeyboardKey.keyZ);
    expect(tester.showsLine('ab'), isTrue);
    await tester.pressCtrl(LogicalKeyboardKey.keyY);
    expect(tester.showsLine('abcd'), isTrue);
    await tester.tapAndSettle(find.byTooltip('Undo'));
    expect(tester.showsLine('ab'), isTrue);
    await tester.tapAndSettle(find.byTooltip('Redo'));

    await tester.leaveExpecting(app, '# Plan\n\nabcd\n');
  });

  testApp('undo tells why there is nothing more only when asked for more', (
    tester,
  ) async {
    await tester.openVisual(app, 'Plan', '# Plan\n\nab\n');
    await tester.clickLine('ab', 2);
    await tester.typeImeText('cd');
    const end =
        'Nothing more to undo since you opened the file. '
        'Older versions are in Backups.';

    await tester.pressCtrl(LogicalKeyboardKey.keyZ);
    expect(tester.showsLine('ab'), isTrue);
    expect(find.text(end), findsNothing);
    // The button looks off, but a tap still tells.
    await tester.tapAndSettle(find.byTooltip('Undo'));
    expect(find.text(end), findsOne);

    await tester.leaveExpecting(app, '# Plan\n\nab\n');
  });

  testApp('Ctrl+Z in Markdown edit undoes and puts the caret at the change', (
    tester,
  ) async {
    await tester.openVisual(app, 'Plan', '# Plan\n\nab\n\nzz\n');
    await tester.chooseMode('Markdown edit');
    await tester.clickLine('ab', 2);
    await tester.typeImeText('cd');
    await tester.clickLine('zz', 0);

    await tester.pressCtrl(LogicalKeyboardKey.keyZ);
    expect(tester.showsLine('ab'), isTrue);
    await tester.typeImeText('x');

    await tester.leaveExpecting(app, '# Plan\n\nabx\n\nzz\n');
  });

  testApp('undo at the start tells why and leads to the backups', (
    tester,
  ) async {
    await planWithBackup(tester);
    await tester.tapAndSettle(find.byType(SuperEditor));
    await tester.typeImeText('more');

    await tester.pressCtrl(LogicalKeyboardKey.keyZ);
    await tester.pressCtrl(LogicalKeyboardKey.keyZ);

    await tester.waitFor(
      find.textContaining('Nothing more to undo since you opened the file.'),
    );
    await tester.tapAndSettle(find.text('Backups'));
    expect(find.text('Backups of Plan'), findsOne);
    expect(find.textContaining('before you edited it'), findsOne);
  });

  testApp('restores a backup into the open document; Undo takes it back', (
    tester,
  ) async {
    await planWithBackup(tester);

    await tester.chooseInMenu('Backups');
    await tester.waitFor(find.textContaining('before you edited it'));
    await tester.tapAndSettle(find.textContaining('before you edited it'));
    await tester.waitFor(find.text('Restore'));
    await tester.keep(find.text('Restore'));

    await tester.waitFor(find.text('Backup restored'));
    await tester.waitFor(find.text('v1', findRichText: true));
    await tester.tapAndSettle(find.byTooltip('Undo'));
    await tester.waitFor(find.text('broken', findRichText: true));
    await tester.tapAndSettle(find.byTooltip('Redo'));
    await tester.pageBack();
    await tester.waitForFile(app.file('plan.md'), '# Plan\nv1\n');
  });

  testApp('a renamed document keeps its backups', (tester) async {
    await planWithBackup(tester);

    await tester.placeNote(name: 'Renamed');
    await tester.waitUntil(() => app.file('Renamed.md').existsSync());
    await tester.chooseInMenu('Backups');

    await tester.waitFor(find.textContaining('before you edited it'));
    expect(find.text('Backups of Plan'), findsOne);
  });

  testApp('deletes a backup', (tester) async {
    await planWithBackup(tester);
    await tester.pageBack();
    await tester.waitForNoteClosed();

    await tester.chooseInMenu('Backups');
    await tester.waitFor(find.textContaining('before you edited it'));
    await tester.tapAndSettle(find.byTooltip('Backup options'));
    await tester.tapAndSettle(find.text('Delete backup'));
    await tester.tapAndSettle(find.text('Delete'));

    await tester.waitFor(find.textContaining('No backups yet.'));
  });
}
