import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/common/moment.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/new_note_session.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_editor_controller.dart';
import 'package:truce_editor/notes/note_files.dart';
import 'package:truce_editor/notes/note_staging.dart';
import 'package:truce_editor/notes/open_note.dart';
import 'package:truce_editor/scan/folder_scans.dart';

import '../support.dart';

void main() {
  late NoteFolder folder;
  late NoteFiles files;
  late Note note;
  late NoteEditSession session;
  late NoteEditorController controller;
  var reach = Reach.reachable;

  setUp(() async {
    reach = Reach.reachable;
    folder = folderAt(tempFolder());
    files = NoteFiles(folder, servicesFor(folder));
    note = (await files.create('a')).value;
    session = NoteEditSession(note, files, tempDrafts());
    addTearDown(session.dispose);
    controller = NoteEditorController(
      OpenNote(session, sessionOf: (_) => throw UnimplementedError()),
      reachSettled: () async => reach,
    );
  });

  FolderScans scans({
    List<Note> notes = const [],
    Map<NoteFolder, StoreError> failed = const {},
    Map<String, List<RelPath>> unreadable = const {},
    Set<NoteKey> unreadNotes = const {},
  }) => FolderScans(
    notes: notes,
    marks: const {},
    subfolders: const {},
    conflicts: FolderConflicts(const []),
    failedFolders: failed,
    unreadable: unreadable,
    startedAt: Moment.now(),
    unreadNotes: unreadNotes,
  );

  Future<Note> changedElsewhere() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await files.save(note, '# a\ntheirs\n');
    return (await files.open(note.path)).value;
  }

  test('takes the latest text a scan found', () async {
    final latest = await changedElsewhere();

    expect(controller.onScans(scans(notes: [latest])), isTrue);
    expect(session.text, '# a\ntheirs\n');
  });

  test('a scan without the note means it was deleted elsewhere', () {
    expect(controller.onScans(scans()), isFalse);
    expect(session.state, EditState.deletedElsewhere);
  });

  test('skips scans in which the note folder failed', () {
    expect(
      controller.onScans(scans(failed: {folder: StoreError.ioFailure})),
      isFalse,
    );
    expect(session.state, EditState.saved);
  });

  test('skips scans that could not read a subfolder above the note', () async {
    Directory('${folder.path}/sub').createSync();
    final inSub = (await files.create('b', subfolder: path('sub'))).value;
    final session = NoteEditSession(inSub, files, tempDrafts());
    addTearDown(session.dispose);
    final open = OpenNote(
      session,
      sessionOf: (_) => throw UnimplementedError(),
    );

    final skipped = NoteEditorController(open, reachSettled: () async => reach)
        .onScans(
          scans(
            unreadable: {
              folder.id: [path('sub')],
            },
          ),
        );

    expect(skipped, isFalse);
    expect(session.state, EditState.saved);
  });

  test('skips scans that could not read the note in its version', () async {
    final older = note;
    session.edit('# a\nmine\n');
    await session.flush();

    // The scan shows the version it read before, as it can't read the file.
    final skipped = controller.onScans(
      scans(notes: [older], unreadNotes: {older.key}),
    );

    expect(skipped, isFalse);
    expect(session.text, '# a\nmine\n');
    expect(session.state, EditState.saved);
  });

  test('a new note has nothing to find in scans', () {
    final open = OpenNote.fresh(
      NewNoteSession(
        (folder: folder, subfolder: null),
        stagingOf: (_) => NoteStaging.unpublished(tempDrafts()),
        create: (_, {required title, required text}) =>
            throw UnimplementedError(),
      ),
      sessionOf: (_) => throw UnimplementedError(),
    );
    addTearDown(open.dispose);

    final fresh = NoteEditorController(open, reachSettled: () async => reach);

    expect(fresh.onScans(scans()), isFalse);
  });

  group('keep', () {
    /// Unsaved edits of a note whose folder is gone, so they can be kept
    /// nowhere in it.
    Future<void> editInGoneFolder() async {
      session.edit('# a\nmine\n');
      final away = Directory(folder.path).renameSync('${folder.path}-away');
      addTearDown(() => away.renameSync(folder.path));
    }

    test('edits saved in the file are kept', () async {
      session.edit('# a\nmine\n');

      expect(await controller.keep(), isTrue);
    });

    test(
      'edits are kept on the device while the folder is unreachable',
      () async {
        reach = Reach.unreachable;
        await editInGoneFolder();

        expect(await controller.keep(), isTrue);
      },
    );

    test('edits are not kept if the folder can be reached', () async {
      reach = Reach.reachable;
      await editInGoneFolder();

      expect(await controller.keep(), isFalse);
    });
  });
}
