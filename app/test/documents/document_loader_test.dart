import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_loader.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/sync_tool/folder_services.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late DocumentFolder folder;
  late FolderServices services;
  late DocumentLoader loader;

  setUp(() {
    dir = tempFolder();
    folder = folderAt(dir);
    services = servicesFor(folder);
    loader = DocumentLoader(services);
  });

  void write(String name, List<int> bytes) => (File(
    '${dir.path}/$name',
  )..createSync(recursive: true)).writeAsBytesSync(bytes);

  /// Loads the documents of the files the folder's scan lists.
  Future<DocumentLoad> loadAll() async =>
      loader.load(folder, (await services.scanner.scan()).value.files);

  /// The documents of [loadAll].
  Future<List<Document>> load() async => (await loadAll()).documents;

  test('reads the scanned documents, not other files', () async {
    write('a.md', '# A'.codeUnits);
    write('sub/b.md', '# B'.codeUnits);
    write('c.txt', 'c'.codeUnits);
    write('a.sync-conflict-20261012-101010-ABCDEFG.md', 'x'.codeUnits);
    write('.stversions/a.md', 'old'.codeUnits);

    final documents = await load();

    expect(
      documents.map((n) => n.path.value),
      unorderedEquals(['a.md', 'sub/b.md']),
    );
    expect(documents.map((n) => n.file.text), unorderedEquals(['# A', '# B']));
  });

  test('leaves out files that are not UTF-8', () async {
    write('bad.md', [0xFF, 0xFE]);

    expect(await load(), isEmpty);
  });

  test('keeps the last version of a document that turned unreadable', () async {
    write('a.md', '# A'.codeUnits);
    final first = (await load()).single;
    write('a.md', [0xFF, 0xFE, 0xFD]);

    final second = (await load()).single;

    expect(identical(first, second), isTrue);
  });

  test('reuses unchanged documents', () async {
    write('a.md', '# A'.codeUnits);
    final first = (await load()).single;

    final second = (await load()).single;

    expect(identical(first, second), isTrue);
  });

  test('keeps the time of a document whose file time went back', () async {
    write('a.md', '# A'.codeUnits);
    File('${dir.path}/a.md').setLastModifiedSync(DateTime(2025));
    await load();
    // Same text, older time: e.g. a stale time right after a write.
    File('${dir.path}/a.md').setLastModifiedSync(DateTime(2024));

    final document = (await load()).single;

    expect(document.modified, DateTime(2025));
    expect(
      document.version,
      (await services.store.read(document.path)).value.version,
    );
  });

  test('takes the time of a changed document, even if older', () async {
    write('a.md', '# A'.codeUnits);
    File('${dir.path}/a.md').setLastModifiedSync(DateTime(2025));
    await load();
    write('a.md', '# B'.codeUnits);
    File('${dir.path}/a.md').setLastModifiedSync(DateTime(2024));

    expect((await load()).single.modified, DateTime(2024));
  });

  test('shows unchanged documents in the folder as now named', () async {
    write('a.md', '# A'.codeUnits);
    await load();
    folder = folder.copyWith(name: 'Renamed');

    expect((await load()).single.folder.name, 'Renamed');
  });

  test('drops a document whose file vanished after the scan', () async {
    write('a.md', '# A'.codeUnits);
    final files = (await services.scanner.scan()).value.files;
    File('${dir.path}/a.md').deleteSync();

    final loaded = await loader.load(folder, files);

    expect(loaded.documents, isEmpty);
    expect(loaded.unread, {path('a.md')});
  });

  test('tells no unread files when all could be read', () async {
    write('a.md', '# A'.codeUnits);
    await load();
    write('a.md', '# B'.codeUnits);

    expect((await loadAll()).unread, isEmpty);
  });

  test('tells a document it kept in its last version as unread', () async {
    write('a.md', '# A'.codeUnits);
    await load();
    write('a.md', [0xFF, 0xFE, 0xFD]);

    final loaded = await loadAll();

    expect(loaded.documents.single.file.text, '# A');
    expect(loaded.unread, {path('a.md')});
  });
}
