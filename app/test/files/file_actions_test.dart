import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/files/file_actions.dart';
import 'package:truce_editor/files/file_settings_controller.dart';
import 'package:truce_editor/files/file_type_selection.dart';
import 'package:truce_editor/files/files_wiring.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folder_selection.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/open_folders_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';

void main() {
  late ProviderContainer container;
  late FileActions actions;
  late Directory work;
  late Directory home;
  late List<Folder> folders;
  late AppStorage storage;
  final markdown = appFileTypes().forNew;

  setUp(() async {
    work = tempFolder();
    home = tempFolder();
    folders = [folderAt(work, id: 'work'), folderAt(home, id: 'home')];
    storage = AppStorage(tempFolder().path);
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        loadedDeviceSettingsProvider.overrideWithValue(DeviceSettings.standard),
      ],
    );
    addTearDown(container.dispose);
    await saveFolders(container, folders);
    actions = container.read(fileActionsProvider);
  });

  /// What the folders hold, listed after every write so far.
  Future<FolderContents> scans() async {
    // The first listing must be done, or the refresh finds no folders yet.
    await container.read(folderContentsProvider.future);
    return (await container.read(folderContentsProvider.notifier).refresh())!;
  }

  File diskFile(Directory dir, String name) => File('${dir.path}/$name');

  /// This device's marks file in [dir].
  String marksFile(Directory dir) =>
      diskFile(dir, '.truce/marks/0123456789abcdef.json').readAsStringSync();

  /// The file [name] in [dir], written as [text] and read.
  Future<FileText> fileIn(Directory dir, String name, String text) async {
    diskFile(dir, name).writeCreatingFolders(text);
    final listed = (await scans()).files.singleWhere(
      (each) => each.path.value == name,
    );
    return (await container
            .read(fileAccessProvider)
            .of(listed.folder)
            .reload(listed))
        .value;
  }

  test('create writes the document', () async {
    await scans();

    final file = (await actions.create(
      (folder: folders[1], subfolder: null),
      type: markdown,
      title: 'Plan',
      text: 'Plan\nsteps\n',
    )).value;

    expect(diskFile(home, 'Plan.md').readAsStringSync(), 'Plan\nsteps\n');
    expect((await scans()).findFile(file.key), isNotNull);
  });

  test('an action before the first scan does not wait forever', () async {
    // Drafts are recovered first, so the action's rescan can run.
    final created = await actions.create(
      (folder: folders[0], subfolder: null),
      type: markdown,
      title: 'Plan',
      text: 'Plan\n',
    );

    expect((await scans()).findFile(created.value.key), isNotNull);
  });

  test('create puts the document in the chosen subfolder', () async {
    Directory('${work.path}/a/b').createSync(recursive: true);
    await scans();

    final file = (await actions.create(
      (folder: folders[0], subfolder: path('a/b')),
      type: markdown,
      title: 'Plan',
      text: '# Plan\n',
    )).value;

    expect(diskFile(work, 'a/b/Plan.md').readAsStringSync(), '# Plan\n');
    expect((await scans()).findFile(file.key)?.path, path('a/b/Plan.md'));
  });

  test('can hold files only in folders the plugin shows', () async {
    await container.read(foldersProvider.future);
    expect(actions.canHold(folders[0], path('docs/new')), isTrue);
    expect(actions.canHold(folders[0], path('docs/.hidden/new')), isFalse);
    expect(actions.canHold(folders[0], path('.stversions')), isFalse);
  });

  group('newFilePlace', () {
    Future<void> setPlace(NewFilePlaceSetting? place) => container
        .read(deviceSettingsProvider.notifier)
        .change((settings) => settings.copyWith(newFilePlace: () => place));

    test('is the first folder without a setting', () async {
      expect(actions.newFilePlace(folders), (
        folder: folders[0],
        subfolder: null,
      ));
    });

    test('is the first folder the grid is filtered to', () async {
      container.read(pickedFoldersProvider.notifier).toggle(folders[1].id);

      expect(actions.newFilePlace(folders), (
        folder: folders[1],
        subfolder: null,
      ));
    });

    test('a new file in a folder or of a type not picked is let through', () {
      container.read(pickedFoldersProvider.notifier).toggle(folders[0].id);
      container
          .read(pickedFileTypesProvider.notifier)
          .toggle(markdown.support.type);
      const other = FileType('other');

      actions.reveal(topOf(folders[1]), other);

      expect(container.read(pickedFoldersProvider), {
        folders[0].id,
        folders[1].id,
      });
      expect(container.read(pickedFileTypesProvider), {
        markdown.support.type,
        other,
      });
    });

    test('is the place set, with a subfolder that is there', () async {
      await fileIn(home, 'inbox/a.md', 'a');
      await setPlace((folderId: folders[1].id, subfolder: path('inbox')));

      expect(actions.newFilePlace(folders), (
        folder: folders[1],
        subfolder: path('inbox'),
      ));
    });

    test('falls back to the default for a folder not offered', () async {
      await setPlace((folderId: folders[1].id, subfolder: null));

      expect(actions.newFilePlace([folders[0]]), (
        folder: folders[0],
        subfolder: null,
      ));
    });
  });

  group('move', () {
    test('moves the document with its color and settings', () async {
      final file = await fileIn(work, 'plan.md', '# Plan\r\n');
      await fileIn(home, 'inbox/other.md', 'x');
      final settings = container.read(fileSettingsProvider.notifier);
      const mark = FileMark(color: 'teal');
      final mine = FileSettings(
        pinned: true,
        view: ViewSettings({'mode': 'visual'}),
      );
      await actions.setMark(file.listed, mark);
      await settings.edit(file.key, (_) => mine);

      final moved = (await actions.move(file, (
        folder: folders[1],
        subfolder: path('inbox'),
      ))).value;

      expect(moved.path, path('inbox/plan.md'));
      expect(diskFile(work, 'plan.md').existsSync(), isFalse);
      expect(diskFile(home, 'inbox/plan.md').readAsStringSync(), '# Plan\r\n');
      expect((await scans()).markOf(moved.key), mark);
      expect(marksFile(work), isNot(contains('plan.md')));
      expect(settings.settingsOf(moved.key), mine);
      expect(settings.settingsOf(file.key), FileSettings.defaults);
    });

    test(
      'asked right after a color, waits for it and takes it along',
      () async {
        final file = await fileIn(work, 'plan.md', '# Plan\n');
        const mark = FileMark(color: 'teal');

        final marked = actions.setMark(file.listed, mark);
        final moved = actions.move(file, (folder: folders[1], subfolder: null));

        expect(await marked, isA<Ok<void, StoreError>>());
        final copy = (await moved).value;
        expect((await scans()).markOf(copy.key), mark);
        expect(marksFile(work), isNot(contains('plan.md')));
      },
    );

    test('renames the document, keeping its extension', () async {
      final file = await fileIn(work, 'plan.MD', 'a');

      final moved = (await actions.move(file, (
        folder: folders[0],
        subfolder: null,
      ), title: 'Ideas')).value;

      expect(moved.path, path('Ideas.MD'));
      expect(diskFile(work, 'Ideas.MD').readAsStringSync(), 'a');
      expect(diskFile(work, 'plan.MD').existsSync(), isFalse);
    });

    test('takes a free name in the new place', () async {
      final file = await fileIn(work, 'plan.md', 'a');
      diskFile(home, 'plan.md').writeAsStringSync('taken');

      final moved = (await actions.move(file, (
        folder: folders[1],
        subfolder: null,
      ))).value;

      expect(moved.path, path('plan 2.md'));
      expect(diskFile(home, 'plan.md').readAsStringSync(), 'taken');
    });

    test('is refused while a sync conflict of the document waits', () async {
      diskFile(
        work,
        'plan.sync-conflict-20261003-134809-4I343AW.md',
      ).writeAsStringSync('b');
      final file = await fileIn(work, 'plan.md', 'a');

      final moved = await actions.move(file, (
        folder: folders[1],
        subfolder: null,
      ));

      expect(moved.error, isA<MoveBlockedByConflict>());
      expect(diskFile(work, 'plan.md').existsSync(), isTrue);
      expect(home.listSync(), isEmpty);
    });

    test('moves nothing once the old file changed meanwhile', () async {
      final file = await fileIn(work, 'plan.md', 'a');
      diskFile(work, 'plan.md').writeAsStringSync('changed elsewhere');

      final moved = await actions.move(file, (
        folder: folders[1],
        subfolder: null,
      ));

      expect(
        moved.error,
        isA<MoveNotWritten>().having(
          (failure) => failure.error,
          'error',
          StoreError.changedSinceRead,
        ),
      );
      expect(diskFile(work, 'plan.md').readAsStringSync(), 'changed elsewhere');
      expect(diskFile(home, 'plan.md').existsSync(), isFalse);
    });
  });

  group('move within one folder', () {
    test('moves the file itself, byte for byte', () async {
      final file = await fileIn(work, 'a/plan.md', '\uFEFF# Plan\r\n');
      Directory('${work.path}/b').createSync();

      final moved = (await actions.move(file, (
        folder: folders[0],
        subfolder: path('b'),
      ))).value;

      expect(moved.key, (folder: folders[0].id, path: path('b/plan.md')));
      expect(diskFile(work, 'b/plan.md').readAsBytesSync(), [
        ...[0xEF, 0xBB, 0xBF],
        ...'# Plan\r\n'.codeUnits,
      ]);
      expect(diskFile(work, 'a/plan.md').existsSync(), isFalse);
    });

    test('moves nothing once the file changed elsewhere', () async {
      final file = await fileIn(work, 'a/plan.md', 'a');
      Directory('${work.path}/b').createSync();
      diskFile(work, 'a/plan.md').writeAsStringSync('changed elsewhere');

      final moved = await actions.move(file, (
        folder: folders[0],
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
      expect(
        diskFile(work, 'a/plan.md').readAsStringSync(),
        'changed elsewhere',
      );
      expect(diskFile(work, 'b/plan.md').existsSync(), isFalse);
    });
  });

  test(
    'delete is refused while a sync conflict of the document waits',
    () async {
      diskFile(
        work,
        'plan.sync-conflict-20261003-134809-4I343AW.md',
      ).writeAsStringSync('b');
      final file = await fileIn(work, 'plan.md', 'a');

      final deleted = await actions.delete(file, 'a');

      expect(deleted.error, isA<DeleteBlockedByConflict>());
      expect(diskFile(work, 'plan.md').existsSync(), isTrue);
    },
  );

  test('delete removes the document; undo writes it back', () async {
    final file = await fileIn(work, 'plan.md', '# Plan\n');

    final deleted = (await actions.delete(file, '# Plan\nmine\n')).value;
    expect(diskFile(work, 'plan.md').existsSync(), isFalse);

    expect(await actions.undoDelete(deleted), isA<Ok<void, StoreError>>());
    expect(diskFile(work, 'plan.md').readAsStringSync(), '# Plan\nmine\n');
    expect((await scans()).findFile(file.key), isNotNull);
  });

  test('delete keeps the mark and settings, so a restore at the same '
      'place soon brings them back; undo brings them back too', () async {
    final file = await fileIn(work, 'plan.md', '# Plan\n');
    final settings = container.read(fileSettingsProvider.notifier);
    const mark = FileMark(color: 'teal');
    final mine = FileSettings(
      pinned: true,
      view: ViewSettings({'mode': 'read', 'checked': 'inPlace'}),
    );
    await actions.setMark(file.listed, mark);
    await settings.edit(file.key, (_) => mine);

    final deleted = (await actions.delete(file, '# Plan\n')).value;
    expect(marksFile(work), contains('plan.md'));
    expect(settings.settingsOf(file.key), mine);

    final services = container.read(folderServicesProvider(folders[0].id));
    final backup = (await services.backups.listOf(file.path)).value.single;
    final choice = (await services.restore.load(backup)).value;
    await services.restore.keep(choice, const KeepOther());
    expect((await scans()).markOf(file.key), mark);
    expect(settings.settingsOf(file.key), mine);

    File('${work.path}/plan.md').deleteSync();
    await actions.undoDelete(deleted);
    expect((await scans()).markOf(file.key), mark);
    expect(settings.settingsOf(file.key), mine);
  });

  test('delete keeps a backup of the text deleted', () async {
    final file = await fileIn(work, 'plan.md', '# Plan\r\n');
    final services = container.read(folderServicesProvider(folders[0].id));

    await actions.delete(file, '# Plan\nmine\n');

    final backup = (await services.backups.listOf(file.path)).value.single;
    expect(backup.kind, BackupKind.beforeDelete);
    expect(
      String.fromCharCodes((await services.backups.read(backup)).value),
      '# Plan\r\nmine\r\n',
    );
  });

  test('delete is refused if no backup can be made', () async {
    final file = await fileIn(work, 'plan.md', '# Plan\n');
    // A file where the folder's backups go: none can be saved.
    File(storage.backupsPath(folders[0].id)).writeCreatingFolders('');

    final deleted = await actions.delete(file, '# Plan\n');

    expect(deleted.error, isA<DeleteNotBackedUp>());
    expect(diskFile(work, 'plan.md').existsSync(), isTrue);
  });

  group('restoreAsNew', () {
    /// The backup of [name] in work that deleting it keeps.
    Future<FolderBackup> deletedBackup(String name, String text) async {
      final file = await fileIn(work, name, text);
      await actions.delete(file, text);
      final backups = container
          .read(folderServicesProvider(folders[0].id))
          .backups;
      return (
        folder: folders[0],
        backup: (await backups.listOf(file.path)).value.single,
      );
    }

    test('writes the backup as a new file at the place picked, in '
        'its byte style, with no color or settings', () async {
      final file = await fileIn(work, 'a/plan.md', '# Plan\r\n');
      await actions.setMark(file.listed, const FileMark(color: 'teal'));
      await actions.delete(file, '# Plan\n');
      final backups = container
          .read(folderServicesProvider(folders[0].id))
          .backups;
      final backup = (
        folder: folders[0],
        backup: (await backups.listOf(file.path)).value.single,
      );

      final copy = (await actions.restoreAsNew(backup, (
        folder: folders[1],
        subfolder: RelPath.parse('b'),
      ), newSubfolder: true)).value;

      expect(copy.path.value, 'b/plan.md');
      expect(diskFile(home, 'b/plan.md').readAsStringSync(), '# Plan\r\n');
      final scan = await scans();
      expect(scan.markOf(copy.key), FileMark.none);
      expect(
        container.read(fileSettingsProvider.notifier).settingsOf(copy.key),
        FileSettings.defaults,
      );
    });

    test('never writes over a file: takes the next free name', () async {
      final backup = await deletedBackup('plan.md', '# Plan\nold\n');
      diskFile(work, 'plan.md').writeAsStringSync('# Plan\nnew\n');

      final copy = (await actions.restoreAsNew(backup, (
        folder: folders[0],
        subfolder: null,
      ))).value;

      expect(copy.path.value, 'plan 2.md');
      expect(diskFile(work, 'plan.md').readAsStringSync(), '# Plan\nnew\n');
      expect(diskFile(work, 'plan 2.md').readAsStringSync(), '# Plan\nold\n');
    });

    test('takes the name given, keeping the extension', () async {
      final backup = await deletedBackup('list.txt', 'Milk\n');

      final copy = (await actions.restoreAsNew(backup, (
        folder: folders[0],
        subfolder: null,
      ), title: 'Shopping')).value;

      expect(copy.path.value, 'Shopping.txt');
    });

    test('a backup that is no text is not restored', () async {
      final backup = await deletedBackup('plan.md', '# Plan\n');
      final store = File(
        '${storage.backupsPath(folders[0].id)}/'
        '${backup.backup.storePath.value}',
      );
      store.writeAsBytesSync([0xff, 0xfe, 0x00, 0xd8, 0x00]);

      final restored = await actions.restoreAsNew(backup, (
        folder: folders[0],
        subfolder: null,
      ));

      expect(restored.error, isA<BackupNotText>());
      expect(diskFile(work, 'plan.md').existsSync(), isFalse);
    });
  });

  test(
    'undo of an unmarked document keeps older marks of other devices out',
    () async {
      final file = await fileIn(work, 'plan.md', '# Plan\n');
      final laptop = FileMarks(
        container.read(folderServicesProvider(folders[0].id)).store,
        deviceId: 'laptop',
        now: () => DateTime.utc(2000),
      );
      await laptop.set(file.path, const FileMark(color: 'amber'));
      await actions.setMark(file.listed, const FileMark(color: 'teal'));
      await actions.setMark(file.listed, FileMark.none);

      final deleted = (await actions.delete(file, '# Plan\n')).value;
      await actions.undoDelete(deleted);

      expect((await scans()).markOf(file.key), FileMark.none);
    },
  );

  test('undo onto a taken path brings the mark to the document, not the other '
      'file', () async {
    final file = await fileIn(work, 'plan.md', '# Plan\n');
    await actions.setMark(file.listed, const FileMark(color: 'teal'));
    final deleted = (await actions.delete(file, '# Plan\n')).value;
    diskFile(work, 'plan.md').writeAsStringSync('# Other\n');

    await actions.undoDelete(deleted);

    final scan = await scans();
    final back = scan.files.singleWhere(
      (listed) => listed.path.value == 'plan 2.md',
    );
    expect(scan.markOf(file.key), FileMark.none);
    expect(scan.markOf(back.key), const FileMark(color: 'teal'));
  });

  test('delete fails if the document changed since it was read', () async {
    final file = await fileIn(work, 'plan.md', '# Plan\n');
    diskFile(work, 'plan.md').writeAsStringSync('# Plan\nfrom elsewhere\n');

    final deleted = await actions.delete(file, '# Plan\n');

    expect(
      deleted.error,
      isA<DeleteNotDone>().having(
        (failure) => failure.error,
        'error',
        StoreError.changedSinceRead,
      ),
    );
    expect(diskFile(work, 'plan.md').existsSync(), isTrue);
  });

  test(
    'undo onto a path taken meanwhile keeps both, under a free name',
    () async {
      final file = await fileIn(work, 'plan.md', '# Plan\n');
      final deleted = (await actions.delete(file, '# Plan\nmine\n')).value;
      diskFile(work, 'plan.md').writeAsStringSync('# Plan\nnew\n');

      final undone = await actions.undoDelete(deleted);

      expect(undone, isA<Ok<void, StoreError>>());
      expect(diskFile(work, 'plan.md').readAsStringSync(), '# Plan\nnew\n');
      expect(diskFile(work, 'plan 2.md').readAsStringSync(), '# Plan\nmine\n');
    },
  );

  test('undo in a subfolder onto a taken path stays in it', () async {
    final file = await fileIn(work, 'a/plan.md', '# Plan\n');
    final deleted = (await actions.delete(file, '# Plan\nmine\n')).value;
    diskFile(work, 'a/plan.md').writeAsStringSync('# Plan\nnew\n');

    await actions.undoDelete(deleted);

    expect(diskFile(work, 'a/plan 2.md').readAsStringSync(), '# Plan\nmine\n');
  });

  test('setMark saves the mark', () async {
    final file = await fileIn(work, 'plan.md', '# Plan\n');
    const teal = FileMark(color: 'teal');

    await actions.setMark(file.listed, teal);

    expect((await scans()).markOf(file.key), teal);
    expect(actions.markOf(file.listed), teal);
  });

  test('after a bug in an action, actions fail instead of waiting', () async {
    final buggy = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        fileStepsProvider.overrideWith(
          (ref) => _BuggySteps(ref.watch(filesWorkProvider)),
        ),
      ],
    );
    addTearDown(buggy.dispose);
    final buggyActions = buggy.read(fileActionsProvider);
    final file = await fileIn(work, 'plan.md', '# Plan\n');
    final outcomes = <Result<void, StoreError>>[];

    await runZonedGuarded(() async {
      outcomes
        ..add(await buggyActions.setMark(file.listed, _teal))
        ..add(await buggyActions.setMark(file.listed, _teal));
    }, (_, _) {});

    expect(outcomes, hasLength(2));
    expect(outcomes, everyElement(isA<Err<void, StoreError>>()));
  });

  test('setMark writes nothing if the mark is already set', () async {
    final file = await fileIn(work, 'plan.md', '# Plan\n');

    await actions.setMark(file.listed, FileMark.none);

    expect(Directory('${work.path}/.truce').existsSync(), isFalse);
  });

  test('marks, deletes and restores a document several levels deep', () async {
    await fileIn(work, 'todo.md', '# Root\n');
    final deep = await fileIn(work, 'a/b/c/todo.md', '# Deep\n');
    final root = (await scans()).files.singleWhere(
      (file) => file.path.value == 'todo.md',
    );
    const mark = FileMark(color: 'teal');

    await actions.setMark(deep.listed, mark);

    expect((await scans()).markOf(deep.key), mark);
    expect((await scans()).markOf(root.key), FileMark.none);

    final deleted = (await actions.delete(deep, '# Deep\nmine\n')).value;
    expect(diskFile(work, 'a/b/c/todo.md').existsSync(), isFalse);
    expect(diskFile(work, 'todo.md').existsSync(), isTrue);
    await actions.undoDelete(deleted);
    expect(
      diskFile(work, 'a/b/c/todo.md').readAsStringSync(),
      '# Deep\nmine\n',
    );
    expect((await scans()).markOf(deep.key), mark);
  });
}

const _teal = FileMark(color: 'teal');

/// Steps whose color step has a bug.
final class _BuggySteps extends FileSteps {
  _BuggySteps(super.work);

  @override
  Future<Result<void, StoreError>> setMark(ListedFile file, FileMark mark) =>
      throw StateError('bug');
}
