import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/folders/folder_services.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late NoteFiles files;
  late Note note;
  late NoteEditSession session;
  final later = DateTime.now().add(const Duration(days: 1));

  setUp(() async {
    dir = tempFolder();
    final folder = folderAt(dir);
    files = NoteFiles(folder, FolderServices.syncthing(folder));
    note = (await files.create('a')).value;
    session = NoteEditSession(note, files, saveDelay: Duration.zero);
    addTearDown(session.dispose);
  });

  String onDisk() => File('${dir.path}/a.md').readAsStringSync();

  /// Simulates an edit from another device and returns the new version.
  Future<Note> editElsewhere(String text) async {
    File('${dir.path}/a.md').writeAsStringSync(text);
    return (await files.reload(note)).value;
  }

  test('saves edits', () async {
    session.edit('# a\nmine');
    await session.flush();

    expect(onDisk(), '# a\nmine');
    expect(session.state, EditState.saved);
  });

  test('takes changes from elsewhere while nothing is unsaved', () async {
    final theirs = await editElsewhere('# a\ntheirs');

    final replaced = session.onRescan(theirs, scannedAt: later);

    expect(replaced, isTrue);
    expect(session.text, '# a\ntheirs');
  });

  test('ignores scans that started before its last write', () async {
    session.edit('# a\nmine');
    await session.flush();

    final replaced = session.onRescan(note, scannedAt: DateTime(2000));

    expect(replaced, isFalse);
    expect(session.text, '# a\nmine');
  });

  test('asks before overwriting a change from elsewhere', () async {
    await editElsewhere('# a\ntheirs, longer');
    session.edit('# a\nmine');
    await session.flush();

    expect(session.state, EditState.changedElsewhere);
    expect(onDisk(), '# a\ntheirs, longer');
  });

  test('keep mine overwrites the change from elsewhere', () async {
    await editElsewhere('# a\ntheirs, longer');
    session.edit('# a\nmine');
    await session.flush();

    await session.keepMine();

    expect(onDisk(), '# a\nmine');
    expect(session.state, EditState.saved);
  });

  test('load theirs drops the edits', () async {
    await editElsewhere('# a\ntheirs, longer');
    session.edit('# a\nmine');
    await session.flush();

    session.loadTheirs();

    expect(session.text, '# a\ntheirs, longer');
    expect(session.state, EditState.saved);
  });

  test('writes a note deleted elsewhere again', () async {
    File('${dir.path}/a.md').deleteSync();
    session.edit('# a\nkept');
    await session.flush();

    expect(onDisk(), '# a\nkept');
  });
}
