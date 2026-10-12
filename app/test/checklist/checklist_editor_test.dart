import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/checklist/checklist_editor.dart';
import 'package:truce_editor/folders/folder_services.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late NoteFiles files;
  late NoteEditSession session;
  late ChecklistEditor editor;

  setUp(() async {
    dir = tempFolder();
    final folder = folderAt(dir);
    files = NoteFiles(folder, FolderServices.syncthing(folder));
    final created = (await files.create('list')).value;
    final note = (await files.save(
      created,
      '# list\n- [ ] a\n- [x] b\n',
    )).value;
    session = NoteEditSession(note, files, saveDelay: Duration.zero);
    editor = ChecklistEditor(session);
    addTearDown(() {
      editor.dispose();
      session.dispose();
    });
  });

  int idOf(String text) =>
      editor.list.lines.firstWhere((line) => line.text == text).id;

  test('saves each action to the file', () async {
    editor.toggle(idOf('a'));
    await session.flush();

    expect(
      File('${dir.path}/list.md').readAsStringSync(),
      '# list\n- [x] a\n- [x] b\n',
    );
  });

  test('undo restores the text before clear done', () {
    final before = editor.clearDone();
    expect(session.text, '# list\n- [ ] a\n');

    editor.undo(before);

    expect(session.text, '# list\n- [ ] a\n- [x] b\n');
  });

  test('follows text edited in the text view', () {
    session.edit('# list\n- [ ] c\n');
    session.edit('# list\n- [ ] cd\n');

    expect(editor.list.lines[1].text, 'cd');
  });
}
