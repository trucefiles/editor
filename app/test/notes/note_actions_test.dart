import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folder_selection.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_actions.dart';
import 'package:truce_editor/notes/note_view.dart';
import 'package:truce_editor/notes/note_views_controller.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

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
    file(dir, name)
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
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
      choose(lastUsedFolderIdProvider, 'work');
      choose(selectedFolderIdProvider, 'home');

      expect(actions.defaultFolder(folders).id, 'home');
    });

    test('is the last used folder when the grid shows all', () {
      choose(lastUsedFolderIdProvider, 'home');

      expect(actions.defaultFolder(folders).id, 'home');
    });

    test('skips a remembered folder that was removed', () {
      choose(selectedFolderIdProvider, 'gone');
      choose(lastUsedFolderIdProvider, 'gone');

      expect(actions.defaultFolder(folders).id, 'work');
    });
  });

  test('create writes the note, remembers its folder and rescans', () async {
    await scans();

    final note = (await actions.create('Plan', folders[1])).value;

    expect(file(home, 'Plan.md').readAsStringSync(), '# Plan\n');
    expect(container.read(lastUsedFolderIdProvider), 'home');
    expect((await scans()).findNote(note.key), isNotNull);
  });

  test('create puts the note in the chosen subfolder', () async {
    await scans();

    final note = (await actions.create(
      'Plan',
      folders[0],
      subfolder: path('a/b'),
    )).value;

    expect(file(work, 'a/b/Plan.md').readAsStringSync(), '# Plan\n');
    expect((await scans()).findNote(note.key)?.path, path('a/b/Plan.md'));
  });

  test('delete removes the note; undo writes it back', () async {
    final note = await noteIn(work, 'plan.md', '# Plan\n');

    final deleted = (await actions.delete(note, '# Plan\nmine\n')).value;
    expect(file(work, 'plan.md').existsSync(), isFalse);

    expect(await actions.undoDelete(deleted), isA<Ok<void, StoreError>>());
    expect(file(work, 'plan.md').readAsStringSync(), '# Plan\nmine\n');
    expect((await scans()).findNote(note.key), isNotNull);
  });

  test('delete drops the mark and view; undo brings them back', () async {
    final note = await noteIn(work, 'plan.md', '# Plan\n');
    final views = container.read(noteViewsProvider.notifier);
    const mark = NoteMark(pinned: true, doneSection: false);
    await actions.setMark(note, mark);
    await views.remember(note.key, NoteView.rendered);

    final deleted = (await actions.delete(note, '# Plan\n')).value;
    expect(marksFile(work), isNot(contains('plan.md')));
    expect(views.viewOf(note.key), isNull);

    await actions.undoDelete(deleted);
    expect((await scans()).markOf(note.key), mark);
    expect(views.viewOf(note.key), NoteView.rendered);
  });

  test('a failed undo brings back no mark', () async {
    final note = await noteIn(work, 'plan.md', '# Plan\n');
    await actions.setMark(note, const NoteMark(pinned: true));
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
    const pinned = NoteMark(pinned: true, color: 'teal');

    await actions.setMark(note, pinned);

    expect(actions.markOf(note), pinned);
    expect((await scans()).markOf(note.key), pinned);
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
    const mark = NoteMark(pinned: true, color: 'teal');

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
