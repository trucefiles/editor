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

  setUp(() async {
    folder = folderAt(tempFolder());
    files = NoteFiles(folder, servicesFor(folder));
    note = (await files.create('a')).value;
    final session = NoteEditSession(note, files, tempDrafts());
    addTearDown(session.dispose);
    controller = NoteEditorController(session);
  });

  FolderScans scans({
    List<Note> notes = const [],
    Map<NoteFolder, StoreError> failed = const {},
  }) => FolderScans(
    notes: notes,
    marks: const {},
    subfolders: const {},
    conflicts: FolderConflicts(const []),
    failedFolders: failed,
    startedAt: Moment.now(),
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
}
