import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_scanner.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late NoteScanner scanner;

  setUp(() {
    dir = tempFolder();
    final folder = folderAt(dir);
    scanner = NoteScanner(folder, servicesFor(folder));
  });

  void write(String name, List<int> bytes) => (File(
    '${dir.path}/$name',
  )..createSync(recursive: true)).writeAsBytesSync(bytes);

  test('reads notes recursively and skips other files', () async {
    write('a.md', '# A'.codeUnits);
    write('sub/b.md', '# B'.codeUnits);
    write('c.txt', 'c'.codeUnits);
    write('.hidden.md', 'h'.codeUnits);
    write('a.sync-conflict-20261012-101010-ABCDEFG.md', 'x'.codeUnits);
    write('.stversions/a.md', 'old'.codeUnits);

    final notes = (await scanner.scan()).value;

    expect(
      notes.map((n) => n.path.value),
      unorderedEquals(['a.md', 'sub/b.md']),
    );
  });

  test('leaves out files that are not UTF-8', () async {
    write('bad.md', [0xFF, 0xFE]);

    expect((await scanner.scan()).value, isEmpty);
  });

  test('reuses unchanged notes on rescan', () async {
    write('a.md', '# A'.codeUnits);
    final first = (await scanner.scan()).value.single;

    final second = (await scanner.scan()).value.single;

    expect(identical(first, second), isTrue);
  });
}
