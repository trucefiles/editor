import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/folders/folder_services.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_loader.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late FolderServices services;
  late NoteLoader loader;

  setUp(() {
    dir = tempFolder();
    final folder = folderAt(dir);
    services = servicesFor(folder);
    loader = NoteLoader(folder, services);
  });

  void write(String name, List<int> bytes) => (File(
    '${dir.path}/$name',
  )..createSync(recursive: true)).writeAsBytesSync(bytes);

  /// Loads the notes of the files the folder's scan lists.
  Future<List<Note>> load() async =>
      loader.load((await services.scanner.scan()).value.files);

  test('reads the scanned notes, not other files', () async {
    write('a.md', '# A'.codeUnits);
    write('sub/b.md', '# B'.codeUnits);
    write('c.txt', 'c'.codeUnits);
    write('a.sync-conflict-20261012-101010-ABCDEFG.md', 'x'.codeUnits);
    write('.stversions/a.md', 'old'.codeUnits);

    final notes = await load();

    expect(
      notes.map((n) => n.path.value),
      unorderedEquals(['a.md', 'sub/b.md']),
    );
    expect(notes.map((n) => n.file.text), unorderedEquals(['# A', '# B']));
  });

  test('leaves out files that are not UTF-8', () async {
    write('bad.md', [0xFF, 0xFE]);

    expect(await load(), isEmpty);
  });

  test('keeps the last version of a note that turned unreadable', () async {
    write('a.md', '# A'.codeUnits);
    final first = (await load()).single;
    write('a.md', [0xFF, 0xFE, 0xFD]);

    final second = (await load()).single;

    expect(identical(first, second), isTrue);
  });

  test('reuses unchanged notes', () async {
    write('a.md', '# A'.codeUnits);
    final first = (await load()).single;

    final second = (await load()).single;

    expect(identical(first, second), isTrue);
  });

  test('keeps the time of a note whose file time went back', () async {
    write('a.md', '# A'.codeUnits);
    File('${dir.path}/a.md').setLastModifiedSync(DateTime(2025));
    await load();
    // Same text, older time: e.g. a stale time right after a write.
    File('${dir.path}/a.md').setLastModifiedSync(DateTime(2024));

    final note = (await load()).single;

    expect(note.modified, DateTime(2025));
    expect(note.version, (await services.store.read(note.path)).value.version);
  });

  test('takes the time of a changed note, even if older', () async {
    write('a.md', '# A'.codeUnits);
    File('${dir.path}/a.md').setLastModifiedSync(DateTime(2025));
    await load();
    write('a.md', '# B'.codeUnits);
    File('${dir.path}/a.md').setLastModifiedSync(DateTime(2024));

    expect((await load()).single.modified, DateTime(2024));
  });

  test('drops a note whose file vanished after the scan', () async {
    write('a.md', '# A'.codeUnits);
    final files = (await services.scanner.scan()).value.files;
    File('${dir.path}/a.md').deleteSync();

    expect(await loader.load(files), isEmpty);
  });
}
