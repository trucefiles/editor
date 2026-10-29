import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truce_folders/truce_folders.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests that try to lose or mix up a user's text: odd names,
/// changes from elsewhere at bad moments, and moves and deletes around
/// them, in the real app on the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/data_edge_cases_test.dart
/// -d linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  /// The texts of the files at the top of the documents folder.
  List<String> topTexts() => [
    for (final file in app.topFiles) file.readAsStringSync(),
  ];

  testApp('a name with % and # saves into its own file', (tester) async {
    app.write('50% #1.md', '# Half\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Half');

    await tester.typeOver('# Half\nv2\n');
    await tester.pageBack();
    await tester.waitForNoteClosed();

    await tester.waitForFile(app.file('50% #1.md'), '# Half\nv2\n');
    expect(app.topFiles, hasLength(1));
  });

  testApp('a picture with a space in its name shows', (tester) async {
    app
      ..write('plan.md', '# Plan\n\n![p](my%20picture.png)\n')
      ..writePicture('my picture.png', width: 2);
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.chooseMode('Read');

    await tester.runFor(const Duration(seconds: 2));

    expect(tester.shownPictureWidth, 2);
  });

  testApp('a change elsewhere to the same text is no clash', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nsame\n');

    app.write('plan.md', '# Plan\nsame\n');
    await tester.tapAndSettle(find.byTooltip('Refresh'));
    await tester.runFor(const Duration(seconds: 2));
    await tester.pageBack();
    await tester.waitForNoteClosed();

    expect(
      find.text('This document changed on another device or app.'),
      findsNothing,
    );
    expect(app.conflictCopies(), isEmpty);
    expect(app.file('plan.md').readAsStringSync(), '# Plan\nsame\n');
  });

  testApp('restoring my text over a file made anew there keeps both', (
    tester,
  ) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nmine\n');
    app.file('plan.md').deleteSync();
    await tester.tapAndSettle(find.byTooltip('Refresh'));
    await tester.waitFor(find.text('Restore with my text'));

    app.write('plan.md', '# Plan\ntheirs\n');
    await tester.tapAndSettle(find.text('Restore with my text'));
    await tester.runFor(const Duration(seconds: 2));
    await tester.pageBack();
    await tester.waitForNoteClosed();
    await tester.runFor(const Duration(seconds: 1));

    expect(topTexts(), containsAll(['# Plan\nmine\n', '# Plan\ntheirs\n']));
  });

  testApp('deleting a document changed elsewhere since keeps that change', (
    tester,
  ) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');

    app.write('plan.md', '# Plan\nv2 from elsewhere\n');
    await tester.chooseInMenu('Delete document');
    await tester.runFor(const Duration(seconds: 2));

    expect(app.file('plan.md').existsSync(), isTrue);
    expect(
      app.file('plan.md').readAsStringSync(),
      '# Plan\nv2 from elsewhere\n',
    );
  });

  testApp('two renames in a row leave one file with the text', (tester) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nv2\n');

    await tester.placeNote(name: 'Ideas');
    await tester.placeNote(name: 'Notes');
    await tester.pageBack();
    await tester.waitForNoteClosed();
    await tester.runFor(const Duration(seconds: 1));

    expect(app.namesIn(), ['Notes.md']);
    expect(app.file('Notes.md').readAsStringSync(), '# Plan\nv2\n');
  });

  testApp('a subfolder renamed elsewhere while open keeps the edits', (
    tester,
  ) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('inbox/plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nmine\n');

    app.folder('inbox').renameSync(app.folder('archive').path);
    await tester.tapAndSettle(find.byTooltip('Refresh'));
    await tester.runFor(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.waitForNoteClosed();
    await tester.runFor(const Duration(seconds: 1));

    final texts = [
      for (final entry in app.documents.listSync(recursive: true))
        if (entry is File) entry.readAsStringSync(),
    ];
    expect(texts, contains('# Plan\nmine\n'));
  });

  testApp('a very long first line still names a file that saves', (
    tester,
  ) async {
    await tester.addFolder(app);
    final title = 'Ünïcödé 😀 ${'long title ' * 25}';

    await tester.typeNewNote('$title\nbody');
    await tester.pageBack();
    await tester.waitForNoteClosed();
    await tester.runFor(const Duration(seconds: 2));

    final file = app.topFiles.single;
    expect(file.readAsStringSync(), contains('body'));
    expect(file.uri.pathSegments.last.length, lessThan(255));
  });

  testApp('moving to another folder with unsaved edits takes them along', (
    tester,
  ) async {
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.addWorkFolder();
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nmine\n');

    await tester.placeNote(folder: 'Work');
    await tester.pageBack();
    await tester.waitForNoteClosed();

    await tester.waitForFile(
      File('${app.work.path}/plan.md'),
      '# Plan\nmine\n',
    );
    expect(app.topFiles, isEmpty);
  });

  testApp('keeping mine after theirs changed again keeps their newest', (
    tester,
  ) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nmine\n');
    app.write('plan.md', '# Plan\nv2 from elsewhere\n');
    await tester.tapAndSettle(find.byTooltip('Refresh'));
    await tester.openCompare();

    app.write('plan.md', '# Plan\nv3 from elsewhere\n');
    await tester.keep(find.text('Keep this').last);
    await tester.runFor(const Duration(seconds: 2));

    expect(
      app.file('plan.md').readAsStringSync(),
      '# Plan\nv3 from elsewhere\n',
    );
  });

  testApp('a file that turns into bytes that are not text is never written '
      'over', (tester) async {
    await app.useRefresh(RefreshMode.manual);
    app.write('plan.md', '# Plan\nv1\n');
    await tester.addFolder(app);
    await tester.openDocument('Plan');
    await tester.typeOver('# Plan\nmine\n');

    final notText = [0x23, 0x20, 0xFF, 0xFE, 0x0A];
    app.file('plan.md').writeAsBytesSync(notText);
    await tester.tapAndSettle(find.byTooltip('Refresh'));
    await tester.runFor(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.runFor(const Duration(seconds: 3));

    expect(app.file('plan.md').readAsBytesSync(), notText);
    expect([
      for (final copy in app.conflictCopies()) copy.readAsStringSync(),
    ], contains('# Plan\nmine\n'));
  });
}
