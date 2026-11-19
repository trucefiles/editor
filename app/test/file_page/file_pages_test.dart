import 'dart:async';
import 'dart:io';

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
  late int closings;

  setUp(() async {
    fixture = await FileFixture.create();
    open = OpenFiles();
    closings = 0;
  });

  FilePages pages({LinkedFiles linked = const NoLinkedFiles()}) => FilePages(
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
    fileClosed: () => closings++,
    endWait: const Duration(seconds: 1),
    linked: linked,
  );

  test('a page tells that it closed, once, as it closes', () async {
    final page = pages().open(fixture.file, withFile: (_) async {});
    expect(closings, 0);

    final closed = page.close();
    expect(closings, 1);
    await closed;

    expect(closings, 1);
  });

  test('an open page is one of the open documents, and closes once its '
      'edits are in the file', () async {
    final page = pages().open(fixture.file, withFile: (_) async {});
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
    final page = pages().open(fixture.file, withFile: (_) async {});
    addTearDown(page.close);
    await page.session.replaceAll('mine\n');

    await open.secureForExit(within: const Duration(seconds: 5));

    expect(fixture.onDisk('a.md'), 'mine\n');
  });

  test("a new document's page goes where it is placed, of the type it was "
      'made as', () {
    final made = pages();
    final document = made.types.newFileChoices.first;
    final page = made.openNew(
      (folder: fixture.folders[1], subfolder: null),
      made: document,
      withFile: (_) async {},
    );
    addTearDown(page.close);

    final file = page.session.file as NewFile;
    expect(file.folder.id, folderId('f2'));
    expect(file.type, same(document.type));
    expect(page.type, same(document.type));
  });

  group("a new document's place changed before its first save", () {
    late _FakeLinked linked;
    late FilePage page;

    setUp(() async {
      linked = _FakeLinked();
      final made = pages(linked: linked);
      page = made.openNew(
        (folder: fixture.folders[0], subfolder: null),
        made: made.types.newFileChoices.first,
        withFile: (_) async {},
      );
      addTearDown(page.close);
      await page.session.replaceAll('Plan\n\n![a](x.png)\n');
    });

    test('changes its links with it', () async {
      final placed = await page.session.place(
        NewFile((
          folder: fixture.folders[0],
          subfolder: path('a'),
        ), type: (page.session.file as NewFile).type),
      );

      expect(placed, isA<Ok<void, StoreError>>());
      expect(page.session.text, 'Plan\n\n![a](../x.png)\n');
      expect(linked.copied, isEmpty);
    });

    test('in another folder, copies its images first', () async {
      await page.session.place(
        NewFile((
          folder: fixture.folders[1],
          subfolder: null,
        ), type: (page.session.file as NewFile).type),
      );

      expect(linked.copied, [fixture.folders[1].id]);
      expect(page.session.file.folder, fixture.folders[1]);
    });

    test('a save while its images are copied lands at the new place', () async {
      linked.copying = Completer<void>();
      final placed = page.session.place(
        NewFile((
          folder: fixture.folders[1],
          subfolder: null,
        ), type: (page.session.file as NewFile).type),
      );

      final saved = page.session.secure(SecureReason.hide);
      await pumpEventQueue();
      expect(fixture.dirs[0].listSync().whereType<File>(), hasLength(1));
      linked.copying!.complete();
      await placed;

      expect(await saved, isTrue);
      expect(File('${fixture.dirs[1].path}/Plan.md').existsSync(), isTrue);
    });

    test('edits made while its images are copied change with it', () async {
      linked.copying = Completer<void>();
      final placed = page.session.place(
        NewFile((
          folder: fixture.folders[1],
          subfolder: path('a'),
        ), type: (page.session.file as NewFile).type),
      );

      await page.session.replaceAll('Plan\n\n![a](x.png)\n\nMore\n');
      linked.copying!.complete();
      await placed;

      expect(page.session.text, 'Plan\n\n![a](../x.png)\n\nMore\n');
    });

    test(
      'a second pick waits for the first, and a save lands at the last',
      () async {
        Directory('${fixture.dirs[0].path}/a').createSync();
        linked.copying = Completer<void>();
        final type = (page.session.file as NewFile).type;
        final first = page.session.place(
          NewFile((folder: fixture.folders[1], subfolder: null), type: type),
        );
        final second = page.session.place(
          NewFile((
            folder: fixture.folders[0],
            subfolder: path('a'),
          ), type: type),
        );

        final saved = page.session.secure(SecureReason.hide);
        await pumpEventQueue();
        linked.copying!.complete();
        await (first, second).wait;

        expect(await saved, isTrue);
        expect(linked.copied, [fixture.folders[1].id, fixture.folders[0].id]);
        expect(fixture.dirs[1].listSync(), isEmpty);
        expect(
          File('${fixture.dirs[0].path}/a/Plan.md').readAsStringSync(),
          'Plan\n\n![a](../x.png)\n',
        );
      },
    );

    test('stays where its images can not be copied', () async {
      linked.copyFails = true;

      final placed = await page.session.place(
        NewFile((
          folder: fixture.folders[1],
          subfolder: null,
        ), type: (page.session.file as NewFile).type),
      );

      expect(placed, isA<Err<void, StoreError>>());
      expect(page.session.file.folder, fixture.folders[0]);
    });
  });

  test("a new calendar's page starts as an empty, unnamed calendar", () {
    final health = appFileTypes().newFileChoices.firstWhere(
      (made) => made.label == 'Health calendar',
    );
    final page = pages().openNew(
      (folder: fixture.folders[0], subfolder: null),
      made: health,
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

/// Kept files for links named `x.png`, at the folder's top level.
final class _FakeLinked implements LinkedFiles {
  final List<FolderId> copied = [];
  bool copyFails = false;

  /// While set, a copy waits for it.
  Completer<void>? copying;

  @override
  Future<Result<void, StoreError>> copyFor(
    String text, {
    required Folder from,
    required Folder to,
  }) async {
    await copying?.future;
    if (copyFails) return const Err(StoreError.ioFailure);
    copied.add(to.id);
    return const Ok(null);
  }

  @override
  Future<Result<Relink?, StoreError>> relinkFor(
    String text,
    Folder folder, {
    required RelPath from,
    required RelPath? toFolder,
  }) async => Ok(
    (destination) =>
        destination == 'x.png' && toFolder != null ? '../x.png' : null,
  );

  @override
  Future<void> bringBack(String text, Folder folder) async {}
}
