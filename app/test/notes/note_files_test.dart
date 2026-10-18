import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/notes/note_files.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late NoteFiles files;

  setUp(() {
    dir = tempFolder();
    final folder = folderAt(dir);
    files = NoteFiles(folder, servicesFor(folder));
  });

  String read(String name) => File('${dir.path}/$name').readAsStringSync();

  test('creates a note with a title heading', () async {
    final note = (await files.create('Shopping')).value;

    expect(note.path.value, 'Shopping.md');
    expect(read('Shopping.md'), '# Shopping\n');
  });

  test('creates a note in a subfolder several levels deep', () async {
    Directory('${dir.path}/a/b/c').createSync(recursive: true);
    File('${dir.path}/a/b/c/Shopping.md').writeAsStringSync('taken');

    final note = (await files.create(
      'Shopping',
      subfolder: path('a/b/c'),
    )).value;

    expect(note.path.value, 'a/b/c/Shopping 2.md');
    expect(read('a/b/c/Shopping 2.md'), '# Shopping\n');
    expect(File('${dir.path}/Shopping.md').existsSync(), isFalse);
  });

  test('creates a note holding the given text', () async {
    final note = (await files.create('Milk', text: 'Milk\nEggs\n')).value;

    expect(note.path.value, 'Milk.md');
    expect(read('Milk.md'), 'Milk\nEggs\n');
  });

  test('copies a note in under its name, in its byte style', () async {
    final other = tempFolder();
    final otherFolder = folderAt(other);
    final source = NoteFiles(otherFolder, servicesFor(otherFolder));
    File('${other.path}/Plan.md').writeAsStringSync('\uFEFFa\r\n');
    final note = (await source.open(path('Plan.md'))).value;
    File('${dir.path}/Plan.md').writeAsStringSync('taken');

    final copy = (await files.copyIn(note, 'b\n')).value;

    expect(copy.path.value, 'Plan 2.md');
    expect(File('${dir.path}/Plan 2.md').readAsBytesSync(), [
      ...[0xEF, 0xBB, 0xBF],
      ...'b\r\n'.codeUnits,
    ]);
  });

  test('copies under another name, with the extension kept', () async {
    File('${dir.path}/plan.MD').writeAsStringSync('a');
    final note = (await files.open(path('plan.MD'))).value;

    final copy = (await files.copyIn(note, 'a', title: 'Ideas')).value;

    expect(copy.path.value, 'Ideas.MD');
  });

  test('a new note whose subfolder is gone goes to the top level', () async {
    final created = (await files.create('Milk', subfolder: path('gone'))).value;

    expect(created.path, path('Milk.md'));
    expect(Directory('${dir.path}/gone').existsSync(), isFalse);
  });

  test('never copies into a subfolder deleted meanwhile', () async {
    final note = (await files.create('Milk')).value;

    final copied = await files.copyIn(note, 'Milk', subfolder: path('gone'));

    expect(copied.error, StoreError.notFound);
    expect(Directory('${dir.path}/gone').existsSync(), isFalse);
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
