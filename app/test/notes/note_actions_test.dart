import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folder_selection.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/checked_items.dart';
import 'package:truce_editor/notes/move_failure.dart';
import 'package:truce_editor/notes/new_note_place/new_note_place.dart';
import 'package:truce_editor/notes/new_note_place/new_note_place_controller.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_actions.dart';
import 'package:truce_editor/notes/note_settings.dart';
import 'package:truce_editor/notes/note_settings_controller.dart';
import 'package:truce_editor/notes/note_view.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_editor/sync_tool/folder_services.dart';

import '../support.dart';

void main() {
  late ProviderContainer container;
  late NoteActions actions;
  late Directory work;
  late Directory home;
  late List<NoteFolder> folders;

  setUp(() async {
    work = tempFolder();
    home = tempFolder();
    folders = [folderAt(work, id: 'work'), folderAt(home, id: 'home')];
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(folderSettingsStoreProvider).save(folders);
    actions = container.read(noteActionsProvider);
  });

  Future<FolderScans> scans() => container.read(folderScansProvider.future);

  File file(Directory dir, String name) => File('${dir.path}/$name');

  /// This device's marks file in [dir].
  String marksFile(Directory dir) =>
      file(dir, '.truce/marks/0123456789abcdef.json').readAsStringSync();

  Future<Note> noteIn(Directory dir, String name, String text) async {
    file(dir, name).writeCreatingFolders(text);
    // The first scan must be done, or the refresh finds no folders yet.
    await scans();
    await container.read(folderScansProvider.notifier).refresh();
    return (await scans()).notes.singleWhere((note) => note.path.value == name);
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

  test('create writes the note and rescans', () async {
    await scans();

    final note = (await actions.create(
      (folder: folders[1], subfolder: null),
      title: 'Plan',
      text: 'Plan\nsteps\n',
    )).value;

    expect(file(home, 'Plan.md').readAsStringSync(), 'Plan\nsteps\n');
    expect((await scans()).findNote(note.key), isNotNull);
  });

  test('create puts the note in the chosen subfolder', () async {
    Directory('${work.path}/a/b').createSync(recursive: true);
    await scans();

    final note = (await actions.create(
      (folder: folders[0], subfolder: path('a/b')),
      title: 'Plan',
      text: '# Plan\n',
    )).value;

    expect(file(work, 'a/b/Plan.md').readAsStringSync(), '# Plan\n');
    expect((await scans()).findNote(note.key)?.path, path('a/b/Plan.md'));
  });

  group('newNotePlace', () {
    Future<void> setPlace(NewNotePlaceSetting? place) =>
        container.read(newNotePlaceProvider.notifier).set(place);

    test('is the default folder without a setting', () async {
      await container.read(newNotePlaceProvider.future);

      expect(actions.newNotePlace(folders), (
        folder: folders[0],
        subfolder: null,
      ));
    });

    test('is the place set, with a subfolder that is there', () async {
      await noteIn(home, 'inbox/a.md', 'a');
      await setPlace((folderId: 'home', subfolder: path('inbox')));

      expect(actions.newNotePlace(folders), (
        folder: folders[1],
        subfolder: path('inbox'),
      ));
    });

    test('falls back to the default for a folder not offered', () async {
      await setPlace((folderId: 'home', subfolder: null));

      expect(actions.newNotePlace([folders[0]]), (
        folder: folders[0],
        subfolder: null,
      ));
    });
  });

  group('move', () {
    test('moves the note with its color and settings', () async {
      final note = await noteIn(work, 'plan.md', '# Plan\r\n');
      await noteIn(home, 'inbox/other.md', 'x');
      final settings = container.read(noteSettingsProvider.notifier);
      const mark = NoteMark(color: 'teal');
      const mine = NoteSettings(view: NoteView.list, pinned: true);
      await actions.setMark(note, mark);
      await settings.edit(note.key, (_) => mine);

      final moved = (await actions.move(note, '# Plan\nmore\n', (
        folder: folders[1],
        subfolder: path('inbox'),
      ))).value;

      await container.read(folderScansProvider.notifier).refresh();
      expect(moved.path, path('inbox/plan.md'));
      expect(file(work, 'plan.md').existsSync(), isFalse);
      expect(
        file(home, 'inbox/plan.md').readAsStringSync(),
        '# Plan\r\nmore\r\n',
      );
      expect((await scans()).markOf(moved.key), mark);
      expect(marksFile(work), isNot(contains('plan.md')));
      expect(settings.settingsOf(moved.key), mine);
      expect(settings.settingsOf(note.key), NoteSettings.defaults);
    });

    test('renames the note, keeping its extension', () async {
      final note = await noteIn(work, 'plan.MD', 'a');

      final moved = (await actions.move(note, 'a', (
        folder: folders[0],
        subfolder: null,
      ), title: 'Ideas')).value;

      expect(moved.path, path('Ideas.MD'));
      expect(file(work, 'Ideas.MD').readAsStringSync(), 'a');
      expect(file(work, 'plan.MD').existsSync(), isFalse);
    });

    test('takes a free name in the new place', () async {
      final note = await noteIn(work, 'plan.md', 'a');
      file(home, 'plan.md').writeAsStringSync('taken');

      final moved = (await actions.move(note, 'a', (
        folder: folders[1],
        subfolder: null,
      ))).value;

      expect(moved.path, path('plan 2.md'));
      expect(file(home, 'plan.md').readAsStringSync(), 'taken');
    });

    test('is refused while a sync conflict of the note waits', () async {
      file(
        work,
        'plan.sync-conflict-20261003-134809-4I343AW.md',
      ).writeAsStringSync('b');
      final note = await noteIn(work, 'plan.md', 'a');

      final moved = await actions.move(note, 'a', (
        folder: folders[1],
        subfolder: null,
      ));

      expect(moved.error, isA<MoveBlockedByConflict>());
      expect(file(work, 'plan.md').existsSync(), isTrue);
      expect(home.listSync(), isEmpty);
    });

    test('keeps both if the old file changed meanwhile', () async {
      final note = await noteIn(work, 'plan.md', 'a');
      file(work, 'plan.md').writeAsStringSync('changed elsewhere');

      final moved = await actions.move(note, 'a', (
        folder: folders[1],
        subfolder: null,
      ));

      expect(moved.error, isA<MoveLeftOriginal>());
      expect(file(work, 'plan.md').readAsStringSync(), 'changed elsewhere');
      expect(file(home, 'plan.md').readAsStringSync(), 'a');
    });
  });

  test('delete removes the note; undo writes it back', () async {
    final note = await noteIn(work, 'plan.md', '# Plan\n');

    final deleted = (await actions.delete(note, '# Plan\nmine\n')).value;
    expect(file(work, 'plan.md').existsSync(), isFalse);

    expect(await actions.undoDelete(deleted), isA<Ok<void, StoreError>>());
    expect(file(work, 'plan.md').readAsStringSync(), '# Plan\nmine\n');
    expect((await scans()).findNote(note.key), isNotNull);
  });

  test('delete drops the mark and settings; undo brings them back', () async {
    final note = await noteIn(work, 'plan.md', '# Plan\n');
    final settings = container.read(noteSettingsProvider.notifier);
    const mark = NoteMark(color: 'teal');
    const mine = NoteSettings(
      view: NoteView.rendered,
      pinned: true,
      checkedItems: CheckedItems.inPlace,
    );
    await actions.setMark(note, mark);
    await settings.edit(note.key, (_) => mine);

    final deleted = (await actions.delete(note, '# Plan\n')).value;
    expect(marksFile(work), isNot(contains('plan.md')));
    expect(settings.settingsOf(note.key), NoteSettings.defaults);

    await actions.undoDelete(deleted);
    expect((await scans()).markOf(note.key), mark);
    expect(settings.settingsOf(note.key), mine);
  });

  test(
    'undo of an unmarked note keeps older marks of other devices out',
    () async {
      final note = await noteIn(work, 'plan.md', '# Plan\n');
      final laptop = NoteMarks(
        container.read(folderServicesProvider(folders[0].location)).store,
        deviceId: 'laptop',
        now: () => DateTime.utc(2000),
      );
      await laptop.set(note.path, const NoteMark(color: 'amber'));
      await actions.setMark(note, const NoteMark(color: 'teal'));
      await actions.setMark(note, NoteMark.none);

      final deleted = (await actions.delete(note, '# Plan\n')).value;
      await actions.undoDelete(deleted);

      expect((await scans()).markOf(note.key), NoteMark.none);
    },
  );

  test('a failed undo brings back no mark', () async {
    final note = await noteIn(work, 'plan.md', '# Plan\n');
    await actions.setMark(note, const NoteMark(color: 'teal'));
    final deleted = (await actions.delete(note, '# Plan\n')).value;
    file(work, 'plan.md').writeAsStringSync('# Other\n');

    await actions.undoDelete(deleted);

    expect((await scans()).markOf(note.key), NoteMark.none);
  });

  test('delete fails if the note changed since it was read', () async {
    final note = await noteIn(work, 'plan.md', '# Plan\n');
    file(work, 'plan.md').writeAsStringSync('# Plan\nfrom elsewhere\n');

    final deleted = await actions.delete(note, '# Plan\n');

    expect(deleted.error, StoreError.changedSinceRead);
    expect(file(work, 'plan.md').existsSync(), isTrue);
  });

  test('undo keeps a file created at the same path meanwhile', () async {
    final note = await noteIn(work, 'plan.md', '# Plan\n');
    final deleted = (await actions.delete(note, '# Plan\n')).value;
    file(work, 'plan.md').writeAsStringSync('# Plan\nnew\n');

    final undone = await actions.undoDelete(deleted);

    expect(undone.error, StoreError.alreadyExists);
    expect(file(work, 'plan.md').readAsStringSync(), '# Plan\nnew\n');
  });

  test('setMark saves the mark and rescans', () async {
    final note = await noteIn(work, 'plan.md', '# Plan\n');
    const teal = NoteMark(color: 'teal');

    await actions.setMark(note, teal);

    expect(actions.markOf(note), teal);
    expect((await scans()).markOf(note.key), teal);
  });

  test('setMark writes nothing if the mark is already set', () async {
    final note = await noteIn(work, 'plan.md', '# Plan\n');

    await actions.setMark(note, NoteMark.none);

    expect(Directory('${work.path}/.truce').existsSync(), isFalse);
  });

  test('marks, deletes and restores a note several levels deep', () async {
    await noteIn(work, 'todo.md', '# Root\n');
    final deep = await noteIn(work, 'a/b/c/todo.md', '# Deep\n');
    final root = (await scans()).notes.singleWhere(
      (note) => note.path.value == 'todo.md',
    );
    const mark = NoteMark(color: 'teal');

    await actions.setMark(deep, mark);

    expect((await scans()).markOf(deep.key), mark);
    expect((await scans()).markOf(root.key), NoteMark.none);

    final deleted = (await actions.delete(deep, '# Deep\nmine\n')).value;
    expect(file(work, 'a/b/c/todo.md').existsSync(), isFalse);
    expect(file(work, 'todo.md').existsSync(), isTrue);
    await actions.undoDelete(deleted);
    expect(file(work, 'a/b/c/todo.md').readAsStringSync(), '# Deep\nmine\n');
    expect((await scans()).markOf(deep.key), mark);
  });
}
