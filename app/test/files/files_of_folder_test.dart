import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';

FilesOfFolder filesOf(Folder folder) =>
    FilesOfFolder(folder, servicesFor(folder), appFileTypes());

void main() {
  late Directory dir;
  late FilesOfFolder files;
  final markdown = appFileTypes().forNew;

  setUp(() {
    dir = tempFolder();
    files = filesOf(folderAt(dir));
  });

  String read(String name) => File('${dir.path}/$name').readAsStringSync();

  test('creates a document named after its title', () async {
    final file = (await files.create(
      'Shopping',
      type: markdown,
      text: '# Shopping\n',
    )).value;

    expect(file.path.value, 'Shopping.md');
    expect(read('Shopping.md'), '# Shopping\n');
  });

  test('creates a document in a subfolder several levels deep', () async {
    Directory('${dir.path}/a/b/c').createSync(recursive: true);
    File('${dir.path}/a/b/c/Shopping.md').writeAsStringSync('taken');

    final file = (await files.create(
      'Shopping',
      type: markdown,
      text: '# Shopping\n',
      subfolder: path('a/b/c'),
    )).value;

    expect(file.path.value, 'a/b/c/Shopping 2.md');
    expect(read('a/b/c/Shopping 2.md'), '# Shopping\n');
    expect(File('${dir.path}/Shopping.md').existsSync(), isFalse);
  });

  test('creates a document holding the given text', () async {
    final file = (await files.create(
      'Milk',
      type: markdown,
      text: 'Milk\nEggs\n',
    )).value;

    expect(file.path.value, 'Milk.md');
    expect(read('Milk.md'), 'Milk\nEggs\n');
  });

  test('copies a document in under its name, in its byte style', () async {
    final other = tempFolder();
    final otherFolder = folderAt(other);
    final source = filesOf(otherFolder);
    File('${other.path}/Plan.md').writeAsStringSync('\uFEFFa\r\n');
    final file = (await source.open(path('Plan.md'))).value;
    File('${dir.path}/Plan.md').writeAsStringSync('taken');

    final copy = (await files.copyIn(file, 'b\n')).value;

    expect(copy.path.value, 'Plan 2.md');
    expect(File('${dir.path}/Plan 2.md').readAsBytesSync(), [
      ...[0xEF, 0xBB, 0xBF],
      ...'b\r\n'.codeUnits,
    ]);
  });

  test('copies under another name, with the extension kept', () async {
    File('${dir.path}/plan.MD').writeAsStringSync('a');
    final file = (await files.open(path('plan.MD'))).value;

    final copy = (await files.copyIn(file, 'a', title: 'Ideas')).value;

    expect(copy.path.value, 'Ideas.MD');
  });

  test(
    'a new document whose subfolder is gone goes to the top level',
    () async {
      final created = (await files.create(
        'Milk',
        type: markdown,
        text: '# Milk\n',
        subfolder: path('gone'),
      )).value;

      expect(created.path, path('Milk.md'));
      expect(Directory('${dir.path}/gone').existsSync(), isFalse);
    },
  );

  test('never copies into a subfolder deleted meanwhile', () async {
    final file = (await files.create(
      'Milk',
      type: markdown,
      text: '# Milk\n',
    )).value;

    final copied = await files.copyIn(file, 'Milk', subfolder: path('gone'));

    expect(copied.error, StoreError.notFound);
    expect(Directory('${dir.path}/gone').existsSync(), isFalse);
  });

  test('picks a free name', () async {
    await files.create('Shopping', type: markdown, text: '# Shopping\n');

    final file = (await files.create(
      'Shopping',
      type: markdown,
      text: '# Shopping\n',
    )).value;

    expect(file.path.value, 'Shopping 2.md');
  });

  test('saves in the file\'s line break style', () async {
    final created = (await files.create(
      'a',
      type: markdown,
      text: '# a\n',
    )).value;
    File('${dir.path}/a.md').writeAsStringSync('a\r\n');
    final file = (await files.reload(created.listed)).value;

    final saved = (await files.save(file, 'b\nc\n')).value;

    expect(read('a.md'), 'b\r\nc\r\n');
    expect(saved.textFile.text, 'b\nc\n');
  });

  test('refuses to save over a change from elsewhere', () async {
    final file = (await files.create('a', type: markdown, text: '# a\n')).value;
    File('${dir.path}/a.md').writeAsStringSync('other device, longer');

    expect((await files.save(file, 'mine')).error, StoreError.changedSinceRead);
    expect(read('a.md'), 'other device, longer');
  });

  test('restores a deleted document', () async {
    final file = (await files.create('a', type: markdown, text: '# a\n')).value;
    await files.delete(file.listed);

    await files.restore(file, '# a\nback');

    expect(read('a.md'), '# a\nback');
  });

  group('in a folder of some subfolders', () {
    late FilesOfFolder work;

    setUp(() {
      Directory('${dir.path}/work/inbox').createSync(recursive: true);
      work = filesOf(folderAt(dir, selection: Selection.of([path('work')])));
    });

    test('refuses a file the folder does not show', () async {
      File('${dir.path}/home.md').writeAsStringSync('home');
      File('${dir.path}/work/photo.png').writeAsStringSync('png');

      expect(
        (await work.open(path('home.md'))).error,
        const NotRead(StoreError.outside),
      );
      expect(
        (await work.open(path('work/photo.png'))).error,
        const NotRead(StoreError.outside),
      );
    });

    test('a new document whose subfolder is gone goes to the top of the '
        'folder', () async {
      final created = (await work.create(
        'Milk',
        type: markdown,
        text: '# Milk\n',
        subfolder: path('work/gone'),
      )).value;

      expect(created.path, path('work/Milk.md'));
      expect(File('${dir.path}/Milk.md').existsSync(), isFalse);
    });

    test('makes a new subfolder the user asked for, then the document '
        'in it', () async {
      final created = (await work.create(
        'Milk',
        type: markdown,
        text: '# Milk\n',
        subfolder: path('work/2026/q1'),
        newSubfolder: true,
      )).value;

      expect(created.path, path('work/2026/q1/Milk.md'));
      expect(read('work/2026/q1/Milk.md'), '# Milk\n');
    });

    test('never makes a new subfolder outside what it shows', () async {
      final created = await work.create(
        'Milk',
        type: markdown,
        text: '# Milk\n',
        subfolder: path('home/new'),
        newSubfolder: true,
      );

      expect(created.error, StoreError.outside);
      expect(Directory('${dir.path}/home').existsSync(), isFalse);
    });

    test('never brings back its chosen subfolder once it is gone', () async {
      Directory('${dir.path}/work').deleteSync(recursive: true);

      final created = await work.create(
        'Milk',
        type: markdown,
        text: '# Milk\n',
        subfolder: path('work'),
      );

      expect(created.error, StoreError.notFound);
      expect(Directory('${dir.path}/work').existsSync(), isFalse);
    });
  });

  group('moveIn', () {
    test('moves the file as saved, to a free name', () async {
      File('${dir.path}/Plan.md').writeAsStringSync('\uFEFFa\r\n');
      Directory('${dir.path}/inbox').createSync();
      File('${dir.path}/inbox/Plan.md').writeAsStringSync('taken');
      final file = (await files.open(path('Plan.md'))).value;

      final moved = (await files.moveIn(file, subfolder: path('inbox'))).value;

      expect(moved.path, path('inbox/Plan 2.md'));
      expect(File('${dir.path}/inbox/Plan 2.md').readAsBytesSync(), [
        ...[0xEF, 0xBB, 0xBF],
        ...'a\r\n'.codeUnits,
      ]);
      expect(File('${dir.path}/Plan.md').existsSync(), isFalse);
      expect(read('inbox/Plan.md'), 'taken');
    });

    test('makes a new subfolder the user asked for, then moves in', () async {
      File('${dir.path}/Plan.md').writeAsStringSync('a');
      final file = (await files.open(path('Plan.md'))).value;

      final moved = (await files.moveIn(
        file,
        subfolder: path('inbox/2026'),
        newSubfolder: true,
      )).value;

      expect(moved.path, path('inbox/2026/Plan.md'));
      expect(read('inbox/2026/Plan.md'), 'a');
    });

    test('moves nothing into a missing subfolder not asked for', () async {
      File('${dir.path}/Plan.md').writeAsStringSync('a');
      final file = (await files.open(path('Plan.md'))).value;

      final moved = await files.moveIn(file, subfolder: path('gone'));

      expect(moved.error, StoreError.notFound);
      expect(Directory('${dir.path}/gone').existsSync(), isFalse);
      expect(read('Plan.md'), 'a');
    });

    test('renames, with the extension kept', () async {
      File('${dir.path}/plan.txt').writeAsStringSync('a');
      final file = (await files.open(path('plan.txt'))).value;

      final moved = (await files.moveIn(file, title: 'Ideas')).value;

      expect(moved.path, path('Ideas.txt'));
      expect(moved.type, file.type);
    });

    test('moves nothing once the file changed elsewhere', () async {
      final file = (await files.create(
        'a',
        type: markdown,
        text: '# a\n',
      )).value;
      File('${dir.path}/a.md').writeAsStringSync('other device, longer');

      final moved = await files.moveIn(file, title: 'b');

      expect(moved.error, StoreError.changedSinceRead);
      expect(read('a.md'), 'other device, longer');
      expect(File('${dir.path}/b.md').existsSync(), isFalse);
    });
  });
}
