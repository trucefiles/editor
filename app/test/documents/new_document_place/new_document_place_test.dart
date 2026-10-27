import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/new_document_place/new_document_place.dart';
import 'package:truce_editor/documents/new_document_place/new_document_place_store.dart';

import '../../support.dart';

void main() {
  final documents = folderAt(Directory('/documents'));
  final work = folderAt(Directory('/work'), id: 'f2');

  group('resolveNewNotePlace', () {
    test('finds the folder, with the subfolder as set', () {
      expect(
        resolveNewNotePlace(
          (folderId: 'f2', subfolder: path('inbox')),
          [documents, work],
        ),
        (folder: work, subfolder: path('inbox')),
      );
    });

    test('none for a folder that is not offered, or no setting', () {
      expect(
        resolveNewNotePlace((folderId: 'f9', subfolder: null), [documents]),
        isNull,
      );
      expect(resolveNewNotePlace(null, [documents]), isNull);
    });
  });

  group('NewNotePlaceStore', () {
    late File file;
    late NewNotePlaceStore store;

    setUp(() {
      file = File('${tempFolder().path}/settings/new_note_place.json');
      store = NewNotePlaceStore(file);
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
