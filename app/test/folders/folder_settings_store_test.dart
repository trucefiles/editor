import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/folders/folder_settings_store.dart';
import 'package:truce_editor/folders/note_folder.dart';

import '../support.dart';

void main() {
  late File file;
  late FolderSettingsStore store;

  setUp(() {
    file = File('${tempFolder().path}/settings/folders.json');
    store = FolderSettingsStore(file);
  });

  test('loads nothing before the first save', () async {
    expect((await store.load()).value, isEmpty);
  });

  test('saves and loads folders', () async {
    const folder = NoteFolder(
      id: 'a1',
      path: '/notes',
      name: 'Private',
      color: Color(0xFF3F51B5),
    );

    await store.save([folder]);

    expect((await store.load()).value, [folder]);
  });

  test('reports a damaged file instead of losing it', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('[{"id": 1}]');

    expect((await store.load()).error, SettingsError.corrupt);
  });
}
