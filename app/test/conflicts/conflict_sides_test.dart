import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import '../support.dart';

void main() {
  const copy = 'a.sync-conflict-20261012-101010-ABCDEFG.md';
  late Directory dir;

  setUp(() => dir = tempFolder());

  void write(String name, String text) =>
      File('${dir.path}/$name').writeAsStringSync(text);

  test('reads both sides as text', () async {
    write('a.md', 'current\r\n');
    write(copy, 'other');
    final services = servicesFor(folderAt(dir));
    final conflict = (await services.scanner.scan()).value.conflicts.single;

    final sides = (await ConflictSides.load(services, conflict)).value;

    expect(versionText(sides.current!), 'current\n');
    expect(versionText(sides.other), 'other');
  });

  test('reads old Mac line breaks as line breaks', () async {
    write('a.md', 'one\rtwo');
    write(copy, 'one\r\ntwo');
    final services = servicesFor(folderAt(dir));
    final conflict = (await services.scanner.scan()).value.conflicts.single;

    final sides = (await ConflictSides.load(services, conflict)).value;

    expect(versionText(sides.current!), 'one\ntwo');
    expect(versionText(sides.other), 'one\ntwo');
  });

  test('has no current side when the main file is gone', () async {
    write(copy, 'other');
    final services = servicesFor(folderAt(dir));
    final conflict = (await services.scanner.scan()).value.conflicts.single;

    final sides = (await ConflictSides.load(services, conflict)).value;

    expect(sides.current, isNull);
  });
}
