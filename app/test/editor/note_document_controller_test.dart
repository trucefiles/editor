import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/note_document_controller.dart';
import 'package:truce_editor/notes/checked_items.dart';
import 'package:truce_editor/notes/note_mode.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';

import '../support.dart';
import 'editor_support.dart';

void main() {
  late Directory dir;
  late NoteFiles files;
  late NoteEditSession session;
  late NoteDocumentController editor;

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
    editor = documentOf(session, checkedItems: CheckedItems.inPlace);
    addTearDown(() {
      editor.dispose();
      session.dispose();
    });
  });

  LineId idOf(String text) =>
      editor.lines.lines.firstWhere((line) => line.text == text).id;

  /// Checks or unchecks the item [text] as the editor does.
  void toggle(String text) {
    final line = editor.lines.lines.firstWhere((line) => line.text == text);
    editor.applyEdits([
      BlockChanged(
        line.id,
        ItemBlock(
          kind: ListKind.checkbox,
          depth: 0,
          text: text,
          checked: !line.isChecked,
        ),
      ),
    ]);
  }

  test('saves each action to the file', () async {
    toggle('a');
    await session.flush();

    expect(
      File('${dir.path}/list.md').readAsStringSync(),
      '# list\n- [x] a\n- [x] b\n',
    );
  });

  test('a sorting toggle moves the checked item below the others', () {
    editor.setCheckedItems(CheckedItems.toEnd);
    toggle('a');

    expect(session.text, '# list\n- [x] b\n- [x] a\n');
  });

  test('sorting the checked items saves only if any moved', () {
    var changes = 0;
    session.addListener(() => changes++);
    editor.setCheckedItems(CheckedItems.toEnd, chose: true);
    expect(changes, 0);

    editor.setCheckedItems(CheckedItems.inPlace);
    toggle('a');
    toggle('b');
    editor.setCheckedItems(CheckedItems.toEnd, chose: true);

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
    editor.applyEdits([
      BlockChanged(
        idOf('a'),
        const ItemBlock(kind: ListKind.checkbox, depth: 0, text: 'a2'),
      ),
    ]);

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

    expect(editor.lines.lines[1].text, 'cd');
  });
}
