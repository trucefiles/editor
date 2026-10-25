import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/new_note_session.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_drafts.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';
import 'package:truce_editor/notes/note_staging.dart';
import 'package:truce_editor/notes/open_note.dart';

import '../support.dart';

void main() {
  final later = DateTime.now().add(const Duration(days: 1));
  late Directory dir;
  late NoteFolder folder;
  late NoteFiles files;
  late NoteDrafts drafts;
  late Completer<void>? holdCreate;
  late StoreError? failure;

  setUp(() {
    dir = tempFolder();
    folder = folderAt(dir);
    files = NoteFiles(folder, servicesFor(folder));
    drafts = tempDrafts();
    holdCreate = null;
    failure = null;
  });

  NoteEditSession sessionOf(Note note) =>
      NoteEditSession(note, files, drafts, writtenAt: Moment.now());

  OpenNote fresh() {
    final open = OpenNote.fresh(
      NewNoteSession(
        (folder: folder, subfolder: null),
        stagingOf: (_) => NoteStaging.unpublished(drafts),
        create: (place, {required title, required text}) async {
          await holdCreate?.future;
          if (failure case final error?) return Err(error);
          return files.create(title, subfolder: place.subfolder, text: text);
        },
        remove: files.delete,
      ),
      sessionOf: sessionOf,
    );
    addTearDown(open.dispose);
    return open;
  }

  String read(String name) => File('${dir.path}/$name').readAsStringSync();

  group('a new note', () {
    test('has no file until it is kept', () {
      final open = fresh()..edit('Milk\n');

      expect(open.note, isNull);
      expect(open.path, path('Milk.md'));
      expect(open.folder, folder);
      expect(dir.listSync(), isEmpty);
    });

    test('gets its file as it is kept, and is edited on in it', () async {
      final open = fresh()..edit('Milk\n');

      expect(await open.secure(), isTrue);
      expect(open.pending, isNull);
      expect(open.note?.path, path('Milk.md'));
      expect(read('Milk.md'), 'Milk\n');

      open.edit('Milk\neggs\n');
      await open.flush();
      expect(read('Milk.md'), 'Milk\neggs\n');
      expect(await drafts.all(before: later), isEmpty);
    });

    test('keeps edits typed while its file is created', () async {
      holdCreate = Completer();
      final open = fresh()..edit('Milk\n');

      final kept = open.secure();
      open.edit('Milk\neggs\n');
      holdCreate!.complete();
      await kept;
      await open.secure();

      expect(read('Milk.md'), 'Milk\neggs\n');
    });

    test('an empty one is never written', () async {
      final open = fresh();

      expect(await open.secure(), isTrue);
      expect(open.pending, isNotNull);
      expect(dir.listSync(), isEmpty);
    });

    test('a failed write is not kept', () async {
      failure = StoreError.ioFailure;
      final open = fresh()..edit('Milk\n');

      expect(await open.secure(), isFalse);
      expect(open.state, EditState.saveFailed);
    });
  });

  test('a moved note is edited on in its copy', () async {
    final note = (await files.create('a', text: 'a\n')).value;
    final open = OpenNote(
      NoteEditSession(note, files, drafts),
      sessionOf: sessionOf,
    );
    addTearDown(open.dispose);
    final copy = (await files.copyIn(note, 'a\n', title: 'b')).value;
    await files.delete(note);

    open
      ..edit('a\nmine\n')
      ..moved(copy);
    await open.secure();

    expect(open.path, path('b.md'));
    expect(read('b.md'), 'a\nmine\n');
    expect(File('${dir.path}/a.md').existsSync(), isFalse);
    expect(await drafts.all(before: later), isEmpty);
  });
}
