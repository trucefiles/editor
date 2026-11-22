import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truce_editor/file_page/ui/file_info_panel.dart';
import 'package:truce_editor/file_page/ui/file_place_chip.dart';
import 'package:truce_editor/file_page/ui/file_view_page.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// End-to-end tests of images as files of their own: their cards, their
/// page and its actions, conflicts, backups and adding one, in the real
/// app on the desktop, against a real folder.
///
/// Run on Linux with `flutter test integration_test/images_test.dart -d
/// linux` (in CI under `xvfb-run`), one file per run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;

  setUp(() => app = TestApp.create());

  /// Waits until the image's page has closed.
  Future<void> waitForPageClosed(WidgetTester tester) => tester.waitUntil(
    () => find.byType(FileViewPage).evaluate().isEmpty,
    timeout: const Duration(seconds: 15),
  );

  /// Opens the image titled [title] from Home's Recently edited.
  Future<void> openImage(WidgetTester tester, String title) =>
      tester.openFile(title);

  testApp('an image opens on its page, and shows a change from elsewhere', (
    tester,
  ) async {
    app.writePicture('cat.png', width: 1);
    await tester.addFolder(app);

    await openImage(tester, 'cat');
    await tester.waitUntil(() => tester.shownPictureWidth == 1);
    app.writePicture('cat.png', width: 2);
    await tester.tapAndSettle(find.byTooltip('Refresh'));

    await tester.waitUntil(() => tester.shownPictureWidth == 2);
  });

  testApp('an image fills the page below its bar, under its place', (
    tester,
  ) async {
    app.writePicture('cat.png', width: 1);
    await tester.addFolder(app);
    await openImage(tester, 'cat');
    await tester.waitUntil(() => tester.shownPictureWidth == 1);

    final page = tester.getRect(find.byType(FileViewPage));
    final bar = tester.getRect(find.byType(AppBar));
    final view = find.byType(InteractiveViewer);
    expect(
      tester.getRect(view),
      Rect.fromLTRB(page.left, bar.bottom, page.right, page.bottom),
    );
    expect(
      MediaQuery.paddingOf(tester.element(view)).top,
      tester.getBottomLeft(find.byType(FilePlaceChip)).dy - bar.bottom,
      reason: 'it knows how far its place covers it',
    );
  });

  testApp('an image is renamed from its page', (tester) async {
    app.writePicture('cat.png', width: 1);
    await tester.addFolder(app);
    await openImage(tester, 'cat');

    await tester.placeNote(name: 'dog');

    await tester.waitFor(find.text('Saved as Documents/dog.png'));
    expect(app.namesIn(), ['dog.png']);
  });

  testApp('a deleted image comes back with Undo', (tester) async {
    app.writePicture('cat.png', width: 1);
    await tester.addFolder(app);
    await openImage(tester, 'cat');

    await tester.chooseInMenu('Delete file');
    await tester.waitFor(find.text('File deleted'));
    expect(app.namesIn(), isEmpty);
    await tester.tapAndSettle(find.text('Undo'));

    await tester.waitUntil(() => app.namesIn().contains('cat.png'));
  });

  testApp('a conflict shows both pictures; the other one is kept', (
    tester,
  ) async {
    app
      ..writePicture('cat.png', width: 1)
      ..writePicture('cat.sync-conflict-20261003-134809-ABCDEFG.png', width: 2);
    await tester.addFolder(app);

    await tester.waitFor(find.byTooltip('Conflicts'));
    await tester.tapAndSettle(find.byTooltip('Conflicts'));
    await tester.tapAndSettle(find.text('cat'));
    await tester.waitUntil(
      () => tester.widgetList<RawImage>(find.byType(RawImage)).length == 2,
    );
    await tester.keep(find.text('Keep this').last);

    await tester.waitFor(find.text('No sync conflicts.'));
    expect(app.file('cat.png').readAsBytesSync(), TestApp.picture(2));
  });

  testApp('a deleted image is restored from Backups', (tester) async {
    app.writePicture('cat.png', width: 1);
    await tester.addFolder(app);
    await openImage(tester, 'cat');
    await tester.chooseInMenu('Delete file');
    await tester.waitFor(find.text('File deleted'));

    await tester.chooseInMenu('Backups');
    await tester.tapAndSettle(find.text('cat'));
    await tester.keep(find.text('Restore'));

    await tester.waitUntil(() => app.namesIn().contains('cat.png'));
    expect(app.file('cat.png').readAsBytesSync(), TestApp.picture(1));
  });

  testApp('an added image is written on leaving, and says where', (
    tester,
  ) async {
    app.picking
      ..picked = onePixelPng
      ..name = 'Milk.png';
    await tester.addFolder(app);

    await tester.tapAndSettle(find.byTooltip('New file'));
    // The New file sheet's, over the type chip of the same name.
    await tester.tapAndSettle(find.text('Image').last);
    await tester.waitFor(find.byType(FileViewPage));
    await tester.runFor(const Duration(seconds: 2));
    expect(app.namesIn(), isEmpty);
    await tester.pageBack();

    await tester.waitFor(find.text('Saved to Documents'));
    await waitForPageClosed(tester);
    expect(app.file('Milk.png').readAsBytesSync(), onePixelPng);
    await tester.waitFor(find.text('Milk'));
  });

  testApp('an added image shows it waits on this device, then is saved', (
    tester,
  ) async {
    app.picking
      ..picked = onePixelPng
      ..name = 'Milk.png';
    await tester.addFolder(app);

    await tester.tapAndSettle(find.byTooltip('New file'));
    // The New file sheet's, over the type chip of the same name.
    await tester.tapAndSettle(find.text('Image').last);
    await tester.waitFor(find.byIcon(Icons.save_outlined));
    expect(app.namesIn(), isEmpty);
    await tester.tapAndSettle(find.byIcon(Icons.save_outlined));

    await tester.waitFor(find.byIcon(Icons.cloud_done_outlined));
    expect(app.file('Milk.png').readAsBytesSync(), onePixelPng);
  });

  testApp("File info tells an image's size and dimensions", (tester) async {
    app.writePicture('cat.png', width: 2);
    await tester.addFolder(app);
    await openImage(tester, 'cat');

    await tester.chooseInMenu('File info');

    await tester.waitFor(find.text('Dimensions'));
    expect(find.text('cat.png'), findsOne);
    expect(
      find.descendant(
        of: find.byType(FileInfoPanel),
        matching: find.text('Image'),
      ),
      findsOne,
    );
    expect(find.text('${TestApp.picture(2).length} bytes'), findsOne);
    expect(find.textContaining('2 × '), findsOne);
  });
}
