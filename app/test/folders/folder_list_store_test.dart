import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/base_folder.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folder_list_store.dart';

import '../support.dart';

void main() {
  late File file;
  late FolderListStore store;

  setUp(() {
    file = File('${tempFolder().path}/settings/folder_list.json');
    store = FolderListStore(file);
  });

  test('loads nothing before the first save', () async {
    expect((await store.load()).value, isEmpty);
  });

  test('saves and loads folders, each base folder once', () async {
    const base = BaseFolder(id: 'b1', path: '/sync', toolId: 'syncthing');
    final folders = [
      const DocumentFolder(
        id: 'a1',
        base: base,
        selection: WholeFolder(),
        name: 'Private',
        color: Color(0xFF3F51B5),
      ),
      DocumentFolder(
        id: 'a2',
        base: const BaseFolder(id: 'b2', path: '/other', toolId: 'plain'),
        selection: Selection.of([path('work'), path('home/notes')]),
        name: 'Work',
        color: const Color(0xFF009688),
      ),
    ];

    await store.save(folders);

    expect((await store.load()).value, folders);
  });

  test('reports a damaged file instead of losing it', () async {
    for (final damaged in [
      '[{"id": 1}]',
      '{"baseFolders": [], "folders": [{"id": "a", "base": "gone", '
          '"name": "A", "color": 1}]}',
      '{"baseFolders": [{"id": "b", "path": "/x", "tool": "syncthing"}], '
          '"folders": [{"id": "a", "base": "b", "name": "A", "color": 1, '
          '"subfolders": ["../up"]}]}',
      '{"baseFolders": [{"id": "b", "path": "/x", "tool": "syncthing"}], '
          '"folders": [{"id": "a", "base": "b", "name": "A", "color": 1, '
          '"subfolders": []}]}',
    ]) {
      file.writeCreatingFolders(damaged);

      expect(
        (await store.load()).error,
        SettingsError.corrupt,
        reason: damaged,
      );
    }
  });
}
