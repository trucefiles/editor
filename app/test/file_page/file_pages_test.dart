import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/file_page/file_pages.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import '../support.dart';
import 'file_fixture.dart';

void main() {
  late FileFixture fixture;
  late OpenEdits open;
  late int closings;

  setUp(() async {
    fixture = await FileFixture.create();
    open = OpenEdits();
    closings = 0;
  });

  FilePages pages() => FilePages(
    create: fixture.createFile,
    move: fixture.moveFile,
    delete: (_, _) async => const Err(DeleteNotDone(StoreError.notFound)),
    settingsOf: (_) => FileSettings.defaults,
    editSettings: (_, _) async {},
    filesOf: (folder) => fixture.files[folder.id]!,
    draftsOf: (folder) => fixture.drafts[folder.id]!,
    reachOf: (_) => Reach.reachable,
    reachSettled: (_) async => Reach.reachable,
    openEdits: open,
    fileClosed: () => closings++,
    endWait: const Duration(seconds: 1),
    arrivals: noArrivals(),
  );

  test('a page tells that it closed, once, as it closes', () async {
    final page = pages().open(
      fixture.file,
      type: appTextType(appFileTypes().ofFile(fixture.file.type)),
      withFile: (_) async {},
    );
    expect(closings, 0);

    final closed = page.close();
    expect(closings, 1);
    await closed;

    expect(closings, 1);
  });

  test('an open page is one of the open documents, and closes once its '
      'edits are in the file', () async {
    final page = pages().open(
      fixture.file,
      type: appTextType(appFileTypes().ofFile(fixture.file.type)),
      withFile: (_) async {},
    );
    await page.session.replaceAll('mine\n');

    // A folder change keeps the edits of the open files first.
    await open.secureIn(fixture.folders[0].id, SecureReason.hide);
    expect(fixture.onDisk('a.md'), 'mine\n');

    await page.session.replaceAll('more\n');
    await page.close();

    expect(fixture.onDisk('a.md'), 'more\n');
    expect(page.session.state, isA<Ended>());
  });

  test('as the app ends, every open page keeps its edits, then waits for '
      'its file', () async {
    final page = pages().open(
      fixture.file,
      type: appTextType(appFileTypes().ofFile(fixture.file.type)),
      withFile: (_) async {},
    );
    addTearDown(page.close);
    await page.session.replaceAll('mine\n');

    await open.secureForExit(within: const Duration(seconds: 5));

    expect(fixture.onDisk('a.md'), 'mine\n');
  });

  test("a new document's page goes where it is placed, of the type it was "
      'made as', () {
    final made = pages();
    final document = appFileTypes().newFileChoices.first;
    final page = made.openNew(
      (folder: fixture.folders[1], subfolder: null),
      made: NewFileChoice(document.kind, appTextType(document.type)),
      withFile: (_) async {},
    );
    addTearDown(page.close);

    final file = page.session.file as NewFile;
    expect(file.folder.id, folderId('f2'));
    expect(file.type, same(document.type));
    expect(page.type, same(document.type));
  });

  test("a new calendar's page starts as an empty, unnamed calendar", () {
    final health = appFileTypes().newFileChoices.firstWhere(
      (made) => made.label == 'Health calendar',
    );
    final page = pages().openNew(
      (folder: fixture.folders[0], subfolder: null),
      made: NewFileChoice(health.kind, appTextType(health.type)),
      withFile: (_) async {},
    );
    addTearDown(page.close);

    expect(page.type, health.type);
    expect((page.session.file as NewFile).type, health.type);
    expect(
      (page.part as CalendarEditorPart).owner.state.text,
      newCalendarText('', health: true),
    );
    expect(
      page.session.path,
      path('Health calendar.ics'),
      reason: 'named after its kind until it has a name',
    );
  });
}
