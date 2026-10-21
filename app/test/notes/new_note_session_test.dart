import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/new_note_session.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_drafts.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';
import 'package:truce_editor/notes/note_place.dart';
import 'package:truce_editor/notes/note_staging.dart';

import '../support.dart';

void main() {
  final later = DateTime.now().add(const Duration(days: 1));
  const saveDelay = Duration(milliseconds: 10);
  late NoteFolder work;
  late NoteFolder home;
  late Map<String, NoteDrafts> drafts;
  late List<({NotePlace place, String title, String text})> created;
  late StoreError? failure;
  late List<Note> removed;
  late Completer<void>? holdCreate;
  late NewNoteSession session;

  setUp(() {
    work = folderAt(tempFolder(), id: 'work');
    home = folderAt(tempFolder(), id: 'home');
    drafts = {'work': tempDrafts(), 'home': tempDrafts()};
    created = [];
    failure = null;
    removed = [];
    holdCreate = null;
    session = NewNoteSession(
      (folder: work, subfolder: null),
      stagingOf: (folder) => NoteStaging.unpublished(drafts[folder.id]!),
      create: (place, {required title, required text}) async {
        created.add((place: place, title: title, text: text));
        await holdCreate?.future;
        if (failure case final error?) return Err(error);
        return NoteFiles(
          place.folder,
          servicesFor(place.folder),
        ).create(title, subfolder: place.subfolder, text: text);
      },
      remove: (note) {
        removed.add(note);
        return NoteFiles(note.folder, servicesFor(note.folder)).delete(note);
      },
      saveDelay: saveDelay,
    );
    addTearDown(session.dispose);
  });

  /// Lets the save timer fire, for what must not happen after it; what
  /// must happen is waited for with [eventually].
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 300));

  Future<List<(String, String?, String)>> draftsIn(String folderId) async => [
    for (final draft in await drafts[folderId]!.all(before: later))
      (draft.path.value, draft.base, draft.text),
  ];

  /// Waits until the drafts in folder [folderId] are [expected].
  Future<void> draftsBecome(
    String folderId,
    List<(String, String?, String)> expected,
  ) => eventually(
    () async => const ListEquality<(String, String?, String)>().equals(
      await draftsIn(folderId),
      expected,
    ),
  );

  test('an empty note is never written', () async {
    session
      ..edit('Milk')
      ..edit('  \n');
    await settle();

    expect(await session.write(), const Ok<Note?, StoreError>(null));
    expect(created, isEmpty);
    expect(await draftsIn('work'), isEmpty);
    expect(session.state, EditState.saved);
  });

  test('keeps the text on this device, named by its first line', () async {
    session.edit('# Milk\neggs\n');
    expect(session.state, EditState.unsaved);
    await eventually(() => session.state == EditState.savedOnDevice);

    expect(session.state, EditState.savedOnDevice);
    expect(session.path, path('Milk.md'));
    expect(await draftsIn('work'), [('Milk.md', null, '# Milk\neggs\n')]);
  });

  test('a name set stays; an empty one follows the first line again', () {
    session
      ..edit('Milk')
      ..moveTo((folder: work, subfolder: null), title: 'Milk')
      ..edit('Eggs');
    expect(session.title, 'Eggs');

    session
      ..moveTo((folder: work, subfolder: null), title: 'Shopping')
      ..edit('Bread');
    expect(session.title, 'Shopping');

    session.moveTo((folder: work, subfolder: null), title: ' ');
    expect(session.title, 'Bread');
  });

  test('a new place takes the draft along', () async {
    session.edit('Milk');
    await draftsBecome('work', [('Milk.md', null, 'Milk')]);

    session.moveTo((folder: home, subfolder: path('inbox')), title: '');
    await draftsBecome('home', [('inbox/Milk.md', null, 'Milk')]);
    await draftsBecome('work', []);
  });

  test('write creates the file at its place and drops the draft', () async {
    session.edit('Milk\n');
    await draftsBecome('work', [('Milk.md', null, 'Milk\n')]);

    final note = (await session.write()).value!;
    await draftsBecome('work', []);

    expect(created.single.title, 'Milk');
    expect(created.single.place.folder, work);
    expect(note.path, path('Milk.md'));
    expect(note.file.text, 'Milk\n');
    expect(await draftsIn('work'), isEmpty);
  });

  test('a failed write keeps the text on this device', () async {
    failure = StoreError.ioFailure;
    session.edit('Milk');

    expect((await session.write()).error, StoreError.ioFailure);
    expect(session.state, EditState.saveFailed);
    expect(await draftsIn('work'), [('Milk.md', null, 'Milk')]);
  });

  test('a note dropped while its file is created leaves no file', () async {
    holdCreate = Completer();
    session.edit('Milk');

    final writing = session.write();
    session.discard();
    holdCreate!.complete();

    expect(await writing, const Ok<Note?, StoreError>(null));
    expect(removed.single.path, path('Milk.md'));
    expect(File('${work.path}/Milk.md').existsSync(), isFalse);
  });

  test('discard drops the note', () async {
    session.edit('Milk');
    await draftsBecome('work', [('Milk.md', null, 'Milk')]);

    session.discard();
    await draftsBecome('work', []);

    expect(session.text, '');
    expect(session.state, EditState.saved);
  });
}
