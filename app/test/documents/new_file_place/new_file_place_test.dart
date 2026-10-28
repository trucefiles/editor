import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/new_file_place/new_file_place.dart';
import 'package:truce_editor/documents/new_file_place/new_file_place_store.dart';

import '../../support.dart';

void main() {
  final documents = folderAt(Directory('/documents'));
  final work = folderAt(Directory('/work'), id: 'f2');

  group('resolveNewFilePlace', () {
    test('finds the folder, with the subfolder as set', () {
      expect(
        resolveNewFilePlace(
          (folderId: 'f2', subfolder: path('inbox')),
          [documents, work],
        ),
        (folder: work, subfolder: path('inbox')),
      );
    });

    test('none for a folder that is not offered, or no setting', () {
      expect(
        resolveNewFilePlace((folderId: 'f9', subfolder: null), [documents]),
        isNull,
      );
      expect(resolveNewFilePlace(null, [documents]), isNull);
    });
  });

  group('NewFilePlaceStore', () {
    late File file;
    late NewFilePlaceStore store;

    setUp(() {
      file = File('${tempFolder().path}/settings/new_file_place.json');
      store = NewFilePlaceStore(file);
    });

    test('loads nothing before the first save', () async {
      expect(await store.load(), isNull);
    });

    test('saves and loads a place, and the choice of none', () async {
      await store.save((folderId: 'f1', subfolder: path('a/b')));
      expect(await store.load(), (folderId: 'f1', subfolder: path('a/b')));

      await store.save((folderId: 'f1', subfolder: null));
      expect(await store.load(), (folderId: 'f1', subfolder: null));

      await store.save(null);
      expect(await store.load(), isNull);
    });
  });
}
