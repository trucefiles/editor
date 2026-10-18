import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/quick/quick_note_place.dart';
import 'package:truce_editor/notes/quick/quick_note_place_store.dart';

import '../../support.dart';

void main() {
  final notes = folderAt(Directory('/notes'));
  final work = folderAt(Directory('/work'), id: 'f2');

  group('resolveQuickNotePlace', () {
    test('finds the folder and a subfolder that is still there', () {
      expect(
        resolveQuickNotePlace(
          (folderId: 'f2', subfolder: path('inbox')),
          [notes, work],
          (folder) => [path('inbox')],
        ),
        (folder: work, subfolder: path('inbox')),
      );
    });

    test('a subfolder that is gone gives the top level', () {
      expect(
        resolveQuickNotePlace(
          (folderId: 'f2', subfolder: path('gone')),
          [notes, work],
          (folder) => const [],
        ),
        (folder: work, subfolder: null),
      );
    });

    test('none for a folder that is not offered, or no setting', () {
      expect(
        resolveQuickNotePlace(
          (folderId: 'f9', subfolder: null),
          [notes],
          (folder) => const [],
        ),
        isNull,
      );
      expect(
        resolveQuickNotePlace(null, [notes], (folder) => const []),
        isNull,
      );
    });
  });

  group('QuickNotePlaceStore', () {
    late File file;
    late QuickNotePlaceStore store;

    setUp(() {
      file = File('${tempFolder().path}/settings/quick_note.json');
      store = QuickNotePlaceStore(file);
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
