import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/common/moment.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_editor_controller.dart';
import 'package:truce_editor/notes/note_files.dart';
import 'package:truce_editor/scan/folder_scans.dart';

import '../support.dart';

void main() {
  late NoteFolder folder;
  late NoteFiles files;
  late Note note;
  late NoteEditorController controller;
  var reach = Reach.reachable;

  setUp(() async {
    reach = Reach.reachable;
    folder = folderAt(tempFolder());
    files = NoteFiles(folder, servicesFor(folder));
    note = (await files.create('a')).value;
    final session = NoteEditSession(note, files, tempDrafts());
    addTearDown(session.dispose);
    controller = NoteEditorController(session, reachSettled: () async => reach);
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
    expect(controller.session.text, '# a\ntheirs\n');
  });

  test('a scan without the note means it was deleted elsewhere', () {
    expect(controller.onScans(scans()), isFalse);
    expect(controller.session.state, EditState.deletedElsewhere);
  });

  test('skips scans in which the note folder failed', () {
    expect(
      controller.onScans(scans(failed: {folder: StoreError.ioFailure})),
      isFalse,
    );
    expect(controller.session.state, EditState.saved);
  });

  test('skips scans that could not read a subfolder above the note', () async {
    final inSub = (await files.create('b', subfolder: path('sub'))).value;
    final session = NoteEditSession(inSub, files, tempDrafts());
    addTearDown(session.dispose);

    final skipped =
        NoteEditorController(session, reachSettled: () async => reach).onScans(
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
    controller.session.edit('# a\nmine\n');
    await controller.session.flush();

    // The scan shows the version it read before, as it can't read the file.
    final skipped = controller.onScans(
      scans(notes: [older], unreadNotes: {older.key}),
    );

    expect(skipped, isFalse);
    expect(controller.session.text, '# a\nmine\n');
    expect(controller.session.state, EditState.saved);
  });

  group('keep', () {
    /// Unsaved edits of a note whose folder is gone, so they can be kept
    /// nowhere in it.
    Future<void> editInGoneFolder() async {
      controller.session.edit('# a\nmine\n');
      final away = Directory(folder.path).renameSync('${folder.path}-away');
      addTearDown(() => away.renameSync(folder.path));
    }

    test('edits saved in the file are kept', () async {
      controller.session.edit('# a\nmine\n');

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
