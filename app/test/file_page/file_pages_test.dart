import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/file_page/file_pages.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';
import 'file_fixture.dart';

void main() {
  late FileFixture fixture;
  late OpenFiles open;
  late int listings;

  setUp(() async {
    fixture = await FileFixture.create();
    open = OpenFiles();
    listings = 0;
  });

  FilePages pages({RefreshMode mode = RefreshMode.live}) => FilePages(
    types: appFileTypes(),
    create: fixture.createFile,
    move: fixture.moveFile,
    delete: (_, _) async => const Err(DeleteNotDone(StoreError.notFound)),
    settingsOf: (_) => FileSettings.defaults,
    editSettings: (_, _) async {},
    filesOf: (folder) => fixture.files[folder.id]!,
    draftsOf: (folder) => fixture.drafts[folder.id]!,
    reachOf: (_) => Reach.reachable,
    reachSettled: (_) async => Reach.reachable,
    openFiles: open,
    refresh: () => RefreshSettings.standard.copyWith(mode: mode),
    refreshFolders: () async => listings++,
  );

  test('in Manual mode, closing a page lists the folders again; opening '
      'one does not', () async {
    final page = pages(mode: RefreshMode.manual)
        .open(fixture.file, withFile: (_) async {});
    expect(listings, 0);

    await page.close();

    expect(listings, 1);
  });

  for (final mode in [RefreshMode.live, RefreshMode.periodic]) {
    test('in ${mode.name} mode, opening and closing a page lists no '
        'folder: changes are followed meanwhile', () async {
      final page = pages(mode: mode).open(fixture.file, withFile: (_) async {});
      await page.close();

      expect(listings, 0);
    });
  }

  test('an open page is one of the open documents, and closes once its '
      'edits are in the file', () async {
    final page = pages().open(fixture.file, withFile: (_) async {});
    page.session.replaceAll('mine\n');

    // A folder change keeps the edits of the open files first.
    await open.secureIn(fixture.folders[0].id, SecureReason.hide);
    expect(fixture.onDisk('a.md'), 'mine\n');

    page.session.replaceAll('more\n');
    await page.close();

    expect(fixture.onDisk('a.md'), 'more\n');
    expect(page.session.state, isA<Ended>());
  });

  test("a new document's page goes where it is placed, of the type for new "
      'documents', () {
    final made = pages();
    final page = made.openNew((
      folder: fixture.folders[1],
      subfolder: null,
    ), withFile: (_) async {});
    addTearDown(page.close);

    final file = page.session.file as NewFile;
    expect(file.folder.id, folderId('f2'));
    expect(file.type, same(made.types.forNew));
    expect(page.type, same(made.types.forNew));
  });

  test("a new calendar's page starts as the calendar it was named", () {
    final health = appFileTypes().newFileChoices.firstWhere(
      (made) => made.label == 'Health calendar',
    );
    final page = pages().openNew(
      (folder: fixture.folders[0], subfolder: null),
      made: health,
      name: 'Me',
      withFile: (_) async {},
    );
    addTearDown(page.close);

    expect(page.type, health.type);
    expect((page.session.file as NewFile).type, health.type);
    expect(
      (page.part as CalendarEditorPart).owner.state.text,
      newCalendarText('Me', health: true),
    );
    expect(page.session.path, path('Me.ics'), reason: 'named by its name');
  });
}
