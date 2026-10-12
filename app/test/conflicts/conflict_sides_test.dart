import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/conflicts/conflict_sides.dart';

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
    final conflict = (await services.conflicts.scan()).value.single;

    final sides = (await ConflictSides.load(services, conflict)).value;

    expect(sides.current, 'current\n');
    expect(sides.other, 'other');
  });

  test('has no current side when the main file is gone', () async {
    write(copy, 'other');
    final services = servicesFor(folderAt(dir));
    final conflict = (await services.conflicts.scan()).value.single;

    final sides = (await ConflictSides.load(services, conflict)).value;

    expect(sides.current, isNull);
  });
}
