import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truce_editor/notes/note_colors.dart';
import 'package:truce_editor/notes/ui/note_editor_screen.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of the notes grid and the folders, in the real app on
/// the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/grid_and_folders_test.dart
/// -d linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  /// Pins the note [title] from the grid.
  Future<void> pin(WidgetTester tester, String title) async {
    await tester.longPress(find.text(title));
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.text('Pin'));
    await tester.waitFor(find.byTooltip('Pinned'));
  }

  testWidgets('deletes a note and undoes it', (tester) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openNote('Plan');

    await tester.chooseInMenu('Delete note');
    await tester.waitFor(find.text('Undo'));
    expect(app.file('plan.md').existsSync(), isFalse);
    await tester.tapAndSettle(find.text('Undo'));

    await tester.waitForFile(app.file('plan.md'), '# Plan\nv1\n');
    await tester.waitFor(find.text('Plan'));
  });

  testWidgets('pins a note from the grid', (tester) async {
    app.write('plan.md', '# Plan\n');
    app.write('ideas.md', '# Ideas\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));
    expect(find.text('Others'), findsNothing);

    await pin(tester, 'Plan');

    // In its own section, above the others.
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Pinned'), lessThan(top('Plan')));
    expect(top('Plan'), lessThan(top('Others')));
    expect(top('Others'), lessThan(top('Ideas')));
    // A pin is this device's view, not synced with the folder.
    expect(app.folder('.truce').existsSync(), isFalse);
  });

  testWidgets('pins a note several levels deep from the grid', (tester) async {
    app.write('a/b/c/plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));

    await pin(tester, 'Plan');

    expect(app.namesIn('a/b/c'), ['plan.md']);
  });

  testWidgets('an open note shows its color and last edit', (tester) async {
    app.write('plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));
    // Right click, as with a mouse.
    await tester.tap(
      find.text('Plan'),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.byTooltip('teal'));

    await tester.openNote('Plan');

    final screen = find.byType(NoteEditorScreen);
    await tester.waitFor(screen);
    final scheme = Theme.of(tester.element(screen)).colorScheme;
    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: screen, matching: find.byType(Scaffold)),
    );
    expect(scaffold.backgroundColor, noteTint('teal', scheme));
    expect(find.textContaining('Edited '), findsOne);
  });

  testWidgets('warns about an unsynced folder in full only in Folders', (
    tester,
  ) async {
    await tester.addFolder(app);

    await tester.waitFor(find.byTooltip('Not inside a Syncthing folder'));
    expect(find.textContaining('may not reach'), findsNothing);

    await tester.tapAndSettle(find.byTooltip('Manage folders'));
    await tester.waitFor(find.textContaining('may not reach'));
  });

  testWidgets('removes a folder from the app, keeping its files', (
    tester,
  ) async {
    app.write('plan.md', '# Plan\n');
    await tester.addFolder(app);
    await tester.waitFor(find.text('Plan'));

    await tester.tapAndSettle(find.byTooltip('Manage folders'));
    await tester.tapAndSettle(find.byTooltip('Remove from app'));
    await tester.tapAndSettle(find.text('Remove'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.waitFor(find.text('Add folder'));
    expect(app.file('plan.md').existsSync(), isTrue);
  });
}
