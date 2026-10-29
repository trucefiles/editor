import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/delete_failure.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_actions.dart';
import 'package:truce_editor/documents/document_files.dart';
import 'package:truce_editor/documents/document_settings.dart';
import 'package:truce_editor/documents/document_settings_controller.dart';
import 'package:truce_editor/documents/document_steps.dart';
import 'package:truce_editor/documents/document_text.dart';
import 'package:truce_editor/documents/move_failure.dart';
import 'package:truce_editor/documents/new_file_place/new_file_place.dart';
import 'package:truce_editor/documents/new_file_place/new_file_place_controller.dart';
import 'package:truce_editor/documents/view_settings.dart';
import 'package:truce_editor/folder_state/folder_contents.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folder_selection.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_editor/sync_tool/base_folder_services.dart';

import '../support.dart';

void main() {
  late ProviderContainer container;
  late DocumentActions actions;
  late Directory work;
  late Directory home;
  late List<DocumentFolder> folders;
  final markdown = appDocumentTypes().forNew;

  setUp(() async {
    work = tempFolder();
    home = tempFolder();
    folders = [
      folderAt(work, id: 'work', baseId: 'work'),
      folderAt(home, id: 'home', baseId: 'home'),
    ];
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(folderListStoreProvider).save(folders);
    actions = container.read(documentActionsProvider);
  });

  /// What the folders hold, listed after every write so far.
  Future<FolderContents> scans() async {
    // The first listing must be done, or the refresh finds no folders yet.
    await container.read(folderContentsProvider.future);
    return (await container.read(folderContentsProvider.notifier).refresh())!;
  }

  File file(Directory dir, String name) => File('${dir.path}/$name');

  /// This device's marks file in [dir].
  String marksFile(Directory dir) =>
      file(dir, '.truce/marks/0123456789abcdef.json').readAsStringSync();

  /// The document [name] in [dir], written as [text] and read.
  Future<DocumentText> documentIn(
    Directory dir,
    String name,
    String text,
  ) async {
    file(dir, name).writeCreatingFolders(text);
    final listed = (await scans()).documents.singleWhere(
      (document) => document.path.value == name,
    );
    return (await container
            .read(documentFilesProvider(listed.folder))
            .reload(listed))
        .value;
  }

  group('defaultFolder', () {
    void choose(
      NotifierProvider<FolderIdChoice, String?> choice,
      String? folderId,
    ) => container.read(choice.notifier).choose(folderId);

    test('is the first folder at first', () {
      expect(actions.defaultFolder(folders).id, 'work');
    });

    test('is the folder the grid is filtered to', () {
      choose(selectedFolderIdProvider, 'home');

      expect(actions.defaultFolder(folders).id, 'home');
    });

    test('is the first one offered if the filtered one is not', () {
      choose(selectedFolderIdProvider, 'work');

      expect(actions.defaultFolder([folders[1]]).id, 'home');
    });
  });

  test('create writes the document', () async {
    await scans();

    final document = (await actions.create(
      (folder: folders[1], subfolder: null),
      type: markdown,
      title: 'Plan',
      text: 'Plan\nsteps\n',
    )).value;

    expect(file(home, 'Plan.md').readAsStringSync(), 'Plan\nsteps\n');
    expect((await scans()).findDocument(document.key), isNotNull);
  });

  test('an action before the first scan does not wait forever', () async {
    // Drafts are recovered first, so the action's rescan can run.
    final created = await actions.create(
      (folder: folders[0], subfolder: null),
      type: markdown,
      title: 'Plan',
      text: 'Plan\n',
    );

    expect((await scans()).findDocument(created.value.key), isNotNull);
  });

  test('create puts the document in the chosen subfolder', () async {
    Directory('${work.path}/a/b').createSync(recursive: true);
    await scans();

    final document = (await actions.create(
      (folder: folders[0], subfolder: path('a/b')),
      type: markdown,
      title: 'Plan',
      text: '# Plan\n',
    )).value;

    expect(file(work, 'a/b/Plan.md').readAsStringSync(), '# Plan\n');
    expect(
      (await scans()).findDocument(document.key)?.path,
      path('a/b/Plan.md'),
    );
  });

  group('newFilePlace', () {
    Future<void> setPlace(NewFilePlaceSetting? place) =>
        container.read(newFilePlaceProvider.notifier).set(place);

    test('is the default folder without a setting', () async {
      await container.read(newFilePlaceProvider.future);

      expect(actions.newFilePlace(folders), (
        folder: folders[0],
        subfolder: null,
      ));
    });

    test('is the place set, with a subfolder that is there', () async {
      await documentIn(home, 'inbox/a.md', 'a');
      await setPlace((folderId: 'home', subfolder: path('inbox')));

      expect(actions.newFilePlace(folders), (
        folder: folders[1],
        subfolder: path('inbox'),
      ));
    });

    test('falls back to the default for a folder not offered', () async {
      await setPlace((folderId: 'home', subfolder: null));

      expect(actions.newFilePlace([folders[0]]), (
        folder: folders[0],
        subfolder: null,
      ));
    });
  });

  group('move', () {
    test('moves the document with its color and settings', () async {
      final document = await documentIn(work, 'plan.md', '# Plan\r\n');
      await documentIn(home, 'inbox/other.md', 'x');
      final settings = container.read(documentSettingsProvider.notifier);
      const mark = DocumentMark(color: 'teal');
      final mine = DocumentSettings(
        pinned: true,
        view: ViewSettings({'mode': 'visual'}),
      );
      await actions.setMark(document.document, mark);
      await settings.edit(document.key, (_) => mine);

      final moved = (await actions.move(document, (
        folder: folders[1],
        subfolder: path('inbox'),
      ))).value;

      expect(moved.path, path('inbox/plan.md'));
      expect(file(work, 'plan.md').existsSync(), isFalse);
      expect(file(home, 'inbox/plan.md').readAsStringSync(), '# Plan\r\n');
      expect((await scans()).markOf(moved.key), mark);
      expect(marksFile(work), isNot(contains('plan.md')));
      expect(settings.settingsOf(moved.key), mine);
      expect(settings.settingsOf(document.key), DocumentSettings.defaults);
    });

    test(
      'asked right after a color, waits for it and takes it along',
      () async {
        final document = await documentIn(work, 'plan.md', '# Plan\n');
        const mark = DocumentMark(color: 'teal');

        final marked = actions.setMark(document.document, mark);
        final moved = actions.move(document, (
          folder: folders[1],
          subfolder: null,
        ));

        expect(await marked, isA<Ok<void, StoreError>>());
        final copy = (await moved).value;
        expect((await scans()).markOf(copy.key), mark);
        expect(marksFile(work), isNot(contains('plan.md')));
      },
    );

    test('renames the document, keeping its extension', () async {
      final document = await documentIn(work, 'plan.MD', 'a');

      final moved = (await actions.move(document, (
        folder: folders[0],
        subfolder: null,
      ), title: 'Ideas')).value;

      expect(moved.path, path('Ideas.MD'));
      expect(file(work, 'Ideas.MD').readAsStringSync(), 'a');
      expect(file(work, 'plan.MD').existsSync(), isFalse);
    });

    test('takes a free name in the new place', () async {
      final document = await documentIn(work, 'plan.md', 'a');
      file(home, 'plan.md').writeAsStringSync('taken');

      final moved = (await actions.move(document, (
        folder: folders[1],
        subfolder: null,
      ))).value;

      expect(moved.path, path('plan 2.md'));
      expect(file(home, 'plan.md').readAsStringSync(), 'taken');
    });

    test('is refused while a sync conflict of the document waits', () async {
      file(
        work,
        'plan.sync-conflict-20261003-134809-4I343AW.md',
      ).writeAsStringSync('b');
      final document = await documentIn(work, 'plan.md', 'a');

      final moved = await actions.move(document, (
        folder: folders[1],
        subfolder: null,
      ));

      expect(moved.error, isA<MoveBlockedByConflict>());
      expect(file(work, 'plan.md').existsSync(), isTrue);
      expect(home.listSync(), isEmpty);
    });

    test('keeps both if the old file changed meanwhile', () async {
      final document = await documentIn(work, 'plan.md', 'a');
      file(work, 'plan.md').writeAsStringSync('changed elsewhere');

      final moved = await actions.move(document, (
        folder: folders[1],
        subfolder: null,
      ));

      expect(moved.error, isA<MoveLeftOriginal>());
      expect(file(work, 'plan.md').readAsStringSync(), 'changed elsewhere');
      expect(file(home, 'plan.md').readAsStringSync(), 'a');
    });
  });

  group('move within one base folder', () {
    late List<DocumentFolder> parts;

    setUp(() async {
      parts = [
        folderAt(
          work,
          id: 'a',
          baseId: 'shared',
          selection: Selection.of([path('a')]),
        ),
        folderAt(
          work,
          id: 'b',
          baseId: 'shared',
          selection: Selection.of([path('b')]),
        ),
      ];
      Directory('${work.path}/b').createSync();
      await container.read(folderListStoreProvider).save(parts);
      container.invalidate(folderListOwnerProvider);
      actions = container.read(documentActionsProvider);
    });

    test('moves the file itself to the other folder', () async {
      final document = await documentIn(work, 'a/plan.md', '\uFEFF# Plan\r\n');

      final moved = (await actions.move(document, (
        folder: parts[1],
        subfolder: path('b'),
      ))).value;

      expect(moved.key, (baseId: 'shared', path: path('b/plan.md')));
      expect(moved.folder.id, 'b');
      expect(file(work, 'b/plan.md').readAsBytesSync(), [
        ...[0xEF, 0xBB, 0xBF],
        ...'# Plan\r\n'.codeUnits,
      ]);
      expect(file(work, 'a/plan.md').existsSync(), isFalse);
    });

    test('moves nothing once the file changed elsewhere', () async {
      final document = await documentIn(work, 'a/plan.md', 'a');
      file(work, 'a/plan.md').writeAsStringSync('changed elsewhere');

      final moved = await actions.move(document, (
        folder: parts[1],
        subfolder: path('b'),
      ));

      expect(
        moved.error,
        isA<MoveNotWritten>().having(
          (failure) => failure.error,
          'error',
          StoreError.changedSinceRead,
        ),
      );
      expect(file(work, 'a/plan.md').readAsStringSync(), 'changed elsewhere');
      expect(file(work, 'b/plan.md').existsSync(), isFalse);
    });
  });

  test(
    'delete is refused while a sync conflict of the document waits',
    () async {
      file(
        work,
        'plan.sync-conflict-20261003-134809-4I343AW.md',
      ).writeAsStringSync('b');
      final document = await documentIn(work, 'plan.md', 'a');

      final deleted = await actions.delete(document, 'a');

      expect(deleted.error, isA<DeleteBlockedByConflict>());
      expect(file(work, 'plan.md').existsSync(), isTrue);
    },
  );

  test('delete removes the document; undo writes it back', () async {
    final document = await documentIn(work, 'plan.md', '# Plan\n');

    final deleted = (await actions.delete(document, '# Plan\nmine\n')).value;
    expect(file(work, 'plan.md').existsSync(), isFalse);

    expect(await actions.undoDelete(deleted), isA<Ok<void, StoreError>>());
    expect(file(work, 'plan.md').readAsStringSync(), '# Plan\nmine\n');
    expect((await scans()).findDocument(document.key), isNotNull);
  });

  test('delete drops the mark and settings; undo brings them back', () async {
    final document = await documentIn(work, 'plan.md', '# Plan\n');
    final settings = container.read(documentSettingsProvider.notifier);
    const mark = DocumentMark(color: 'teal');
    final mine = DocumentSettings(
      pinned: true,
      view: ViewSettings({'mode': 'read', 'checked': 'inPlace'}),
    );
    await actions.setMark(document.document, mark);
    await settings.edit(document.key, (_) => mine);

    final deleted = (await actions.delete(document, '# Plan\n')).value;
    expect(marksFile(work), isNot(contains('plan.md')));
    expect(settings.settingsOf(document.key), DocumentSettings.defaults);

    await actions.undoDelete(deleted);
    expect((await scans()).markOf(document.key), mark);
    expect(settings.settingsOf(document.key), mine);
  });

  test(
    'undo of an unmarked document keeps older marks of other devices out',
    () async {
      final document = await documentIn(work, 'plan.md', '# Plan\n');
      final laptop = DocumentMarks(
        container.read(baseFolderServicesProvider(folders[0].base)).store,
        deviceId: 'laptop',
        now: () => DateTime.utc(2000),
      );
      await laptop.set(document.path, const DocumentMark(color: 'amber'));
      await actions.setMark(
        document.document,
        const DocumentMark(color: 'teal'),
      );
      await actions.setMark(document.document, DocumentMark.none);

      final deleted = (await actions.delete(document, '# Plan\n')).value;
      await actions.undoDelete(deleted);

      expect((await scans()).markOf(document.key), DocumentMark.none);
    },
  );

  test('undo onto a taken path brings the mark to the document, not the other '
      'file', () async {
    final document = await documentIn(work, 'plan.md', '# Plan\n');
    await actions.setMark(document.document, const DocumentMark(color: 'teal'));
    final deleted = (await actions.delete(document, '# Plan\n')).value;
    file(work, 'plan.md').writeAsStringSync('# Other\n');

    await actions.undoDelete(deleted);

    final scan = await scans();
    final back = scan.documents.singleWhere(
      (document) => document.path.value == 'plan 2.md',
    );
    expect(scan.markOf(document.key), DocumentMark.none);
    expect(scan.markOf(back.key), const DocumentMark(color: 'teal'));
  });

  test('delete fails if the document changed since it was read', () async {
    final document = await documentIn(work, 'plan.md', '# Plan\n');
    file(work, 'plan.md').writeAsStringSync('# Plan\nfrom elsewhere\n');

    final deleted = await actions.delete(document, '# Plan\n');

    expect(
      deleted.error,
      isA<DeleteNotDone>().having(
        (failure) => failure.error,
        'error',
        StoreError.changedSinceRead,
      ),
    );
    expect(file(work, 'plan.md').existsSync(), isTrue);
  });

  test(
    'undo onto a path taken meanwhile keeps both, under a free name',
    () async {
      final document = await documentIn(work, 'plan.md', '# Plan\n');
      final deleted = (await actions.delete(document, '# Plan\nmine\n')).value;
      file(work, 'plan.md').writeAsStringSync('# Plan\nnew\n');

      final undone = await actions.undoDelete(deleted);

      expect(undone, isA<Ok<void, StoreError>>());
      expect(file(work, 'plan.md').readAsStringSync(), '# Plan\nnew\n');
      expect(file(work, 'plan 2.md').readAsStringSync(), '# Plan\nmine\n');
    },
  );

  test('undo in a subfolder onto a taken path stays in it', () async {
    final document = await documentIn(work, 'a/plan.md', '# Plan\n');
    final deleted = (await actions.delete(document, '# Plan\nmine\n')).value;
    file(work, 'a/plan.md').writeAsStringSync('# Plan\nnew\n');

    await actions.undoDelete(deleted);

    expect(file(work, 'a/plan 2.md').readAsStringSync(), '# Plan\nmine\n');
  });

  test('setMark saves the mark', () async {
    final document = await documentIn(work, 'plan.md', '# Plan\n');
    const teal = DocumentMark(color: 'teal');

    await actions.setMark(document.document, teal);

    expect((await scans()).markOf(document.key), teal);
    expect(actions.markOf(document.document), teal);
  });

  test('after a bug in an action, actions fail instead of waiting', () async {
    final buggy = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        documentStepsProvider.overrideWith(_BuggySteps.new),
      ],
    );
    addTearDown(buggy.dispose);
    final buggyActions = buggy.read(documentActionsProvider);
    final document = await documentIn(work, 'plan.md', '# Plan\n');
    final outcomes = <Result<void, StoreError>>[];

    await runZonedGuarded(() async {
      outcomes
        ..add(await buggyActions.setMark(document.document, _teal))
        ..add(await buggyActions.setMark(document.document, _teal));
    }, (_, _) {});

    expect(outcomes, hasLength(2));
    expect(outcomes, everyElement(isA<Err<void, StoreError>>()));
  });

  test('setMark writes nothing if the mark is already set', () async {
    final document = await documentIn(work, 'plan.md', '# Plan\n');

    await actions.setMark(document.document, DocumentMark.none);

    expect(Directory('${work.path}/.truce').existsSync(), isFalse);
  });

  test('marks, deletes and restores a document several levels deep', () async {
    await documentIn(work, 'todo.md', '# Root\n');
    final deep = await documentIn(work, 'a/b/c/todo.md', '# Deep\n');
    final root = (await scans()).documents.singleWhere(
      (document) => document.path.value == 'todo.md',
    );
    const mark = DocumentMark(color: 'teal');

    await actions.setMark(deep.document, mark);

    expect((await scans()).markOf(deep.key), mark);
    expect((await scans()).markOf(root.key), DocumentMark.none);

    final deleted = (await actions.delete(deep, '# Deep\nmine\n')).value;
    expect(file(work, 'a/b/c/todo.md').existsSync(), isFalse);
    expect(file(work, 'todo.md').existsSync(), isTrue);
    await actions.undoDelete(deleted);
    expect(file(work, 'a/b/c/todo.md').readAsStringSync(), '# Deep\nmine\n');
    expect((await scans()).markOf(deep.key), mark);
  });
}

const _teal = DocumentMark(color: 'teal');

/// Steps whose color step has a bug.
final class _BuggySteps extends DocumentSteps {
  _BuggySteps(super.ref);

  @override
  Future<Result<void, StoreError>> setMark(
    Document document,
    DocumentMark mark,
  ) => throw StateError('bug');
}
