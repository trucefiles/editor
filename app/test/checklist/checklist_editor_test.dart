import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/checklist/checklist_editor.dart';
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
    files = NoteFiles(folder, servicesFor(folder));
    final created = (await files.create('list')).value;
    final note = (await files.save(
      created,
      '# list\n- [ ] a\n- [x] b\n',
    )).value;
    session = NoteEditSession(
      note,
      files,
      tempDrafts(),
      saveDelay: Duration.zero,
    );
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

  test('a sorting toggle moves the checked item below the others', () {
    editor.toggle(idOf('a'), sort: true);

    expect(session.text, '# list\n- [x] b\n- [x] a\n');
  });

  test('sorting the checked items saves only if any moved', () {
    var changes = 0;
    editor
      ..addListener(() => changes++)
      ..sortChecked();
    expect(changes, 0);

    editor.toggle(idOf('a'));
    editor.toggle(idOf('b'));
    editor.sortChecked();

    expect(session.text, '# list\n- [ ] b\n- [x] a\n');
  });

  test('undo restores the text before clear done', () {
    final undo = editor.clearDone();
    expect(session.text, '# list\n- [ ] a\n');

    expect(editor.undo(undo), isTrue);

    expect(session.text, '# list\n- [ ] a\n- [x] b\n');
  });

  test('undo keeps an edit made after the action', () {
    final undo = editor.remove(idOf('b'));
    editor.setText(idOf('a'), 'a2');

    expect(editor.undo(undo), isFalse);

    expect(session.text, '# list\n- [ ] a2\n');
  });

  test('undo keeps a change from elsewhere made after the action', () {
    final undo = editor.clearDone();
    session.edit('# list\n- [ ] from elsewhere\n');

    expect(editor.undo(undo), isFalse);

    expect(session.text, '# list\n- [ ] from elsewhere\n');
  });

  test('follows text edited in the text view', () {
    session.edit('# list\n- [ ] c\n');
    session.edit('# list\n- [ ] cd\n');

    expect(editor.list.lines[1].text, 'cd');
  });
}
