import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late File file;
  late FolderListStore store;

  setUp(() {
    file = File('${tempFolder().path}/settings/folders.json');
    store = FolderListStore(file);
  });

  test('loads nothing before the first save', () async {
    final saved = (await store.load()).value;

    expect(saved.folders, isEmpty);
    expect(saved.blobs, isEmpty);
  });

  test('saves and loads the folders with every plugin blob', () async {
    final folders = [
      (id: folderId('a'), name: 'Private', color: 'indigo'),
      (id: const FolderId('local', 'b'), name: 'Work', color: 'teal'),
    ];
    final blobs = {
      'fake': ['a'],
      'local': {'folders': <Object?>[]},
    };

    await store.save((folders: folders, blobs: blobs));
    final loaded = (await store.load()).value;

    expect(loaded.folders, folders);
    expect(loaded.blobs, blobs);
  });

  test('a file it did not write is corrupt', () async {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync('{"folders": [{"id": 1}], "plugins": {}}');

    expect((await store.load()).error, SettingsError.corrupt);
  });
}
