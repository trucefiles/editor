import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folder_services.dart';
import 'package:truce_editor/notes/note_files.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late NoteFiles files;

  setUp(() {
    dir = tempFolder();
    final folder = folderAt(dir);
    files = NoteFiles(folder, FolderServices.syncthing(folder));
  });

  String read(String name) => File('${dir.path}/$name').readAsStringSync();

  test('creates a note with a title heading', () async {
    final note = (await files.create('Shopping')).value;

    expect(note.path.value, 'Shopping.md');
    expect(read('Shopping.md'), '# Shopping\n');
  });

  test('picks a free name', () async {
    await files.create('Shopping');

    final note = (await files.create('Shopping')).value;

    expect(note.path.value, 'Shopping 2.md');
  });

  test('saves in the file\'s line break style', () async {
    final created = (await files.create('a')).value;
    File('${dir.path}/a.md').writeAsStringSync('a\r\n');
    final note = (await files.reload(created)).value;

    final saved = (await files.save(note, 'b\nc\n')).value;

    expect(read('a.md'), 'b\r\nc\r\n');
    expect(saved.file.text, 'b\nc\n');
  });

  test('refuses to save over a change from elsewhere', () async {
    final note = (await files.create('a')).value;
    File('${dir.path}/a.md').writeAsStringSync('other device, longer');

    expect((await files.save(note, 'mine')).error, StoreError.changedSinceRead);
    expect(read('a.md'), 'other device, longer');
  });

  test('restores a deleted note', () async {
    final note = (await files.create('a')).value;
    await files.delete(note);

    await files.restore(note, '# a\nback');

    expect(read('a.md'), '# a\nback');
  });
}
