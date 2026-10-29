import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  test('saves backups without leaving temp files behind', () async {
    final folder = tempFolder();

    await fileBackupsAt(folder.path).saveBeforeEdit(
      at: DateTime(2026, 10, 15),
      filePath: path('documents/a.md'),
      bytes: utf8.encode('a'),
    );

    final names = folder
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last);
    expect(names, ['a.md']);
  });

  test('a temp file left by a crash is no backup', () async {
    final folder = tempFolder();
    final backups = fileBackupsAt(folder.path);
    await backups.saveBeforeEdit(
      at: DateTime(2026, 10, 15),
      filePath: path('documents/a.md'),
      bytes: utf8.encode('a'),
    );
    final saved = folder.listSync(recursive: true).whereType<File>().single;
    File('${saved.parent.path}/.truce-0123.tmp').writeAsStringSync('a');

    final listed = (await backups.list()).value;

    expect(listed.map((backup) => backup.filePath), [path('documents/a.md')]);
  });
}
