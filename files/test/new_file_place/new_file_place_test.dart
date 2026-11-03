import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

Folder _folder(String id) =>
    Folder(id: folderId(id), name: id, color: 'teal', location: id);

void main() {
  final documents = _folder('f1');
  final work = _folder('f2');

  group('resolveNewFilePlace', () {
    test('finds the folder, with the subfolder as set', () {
      expect(
        resolveNewFilePlace(
          (folderId: folderId('f2'), subfolder: path('inbox')),
          [documents, work],
        ),
        (folder: work, subfolder: path('inbox')),
      );
    });

    test('none for a folder that is not offered, or no setting', () {
      expect(
        resolveNewFilePlace(
          (folderId: folderId('f9'), subfolder: null),
          [documents],
        ),
        isNull,
      );
      expect(resolveNewFilePlace(null, [documents]), isNull);
    });
  });

  group('newFilePlaceIn', () {
    FilePlace? placeIn(
      List<Folder> reachable, {
      NewFilePlaceSetting? set,
      Set<FolderId> filtered = const {},
    }) => newFilePlaceIn(reachable, set: set, filtered: filtered);

    test('is the place set, if its folder can be reached', () {
      final set = (folderId: work.id, subfolder: path('inbox'));

      expect(placeIn([documents, work], set: set, filtered: {documents.id}), (
        folder: work,
        subfolder: path('inbox'),
      ));
      expect(placeIn([documents], set: set), topOf(documents));
    });

    test('else the first filtered folder, else the first', () {
      expect(placeIn([documents, work], filtered: {work.id}), topOf(work));
      expect(
        placeIn([documents, work], filtered: {work.id, documents.id}),
        topOf(documents),
      );
      expect(placeIn([documents], filtered: {work.id}), topOf(documents));
      expect(placeIn([documents, work]), topOf(documents));
    });

    test('none if no folder can be reached', () {
      expect(placeIn(const []), isNull);
    });
  });

  test('reads back what it writes, also the choice of none', () {
    for (final place in [
      (folderId: folderId('f1'), subfolder: path('a/b')),
      (folderId: folderId('f1'), subfolder: null),
      null,
    ]) {
      expect(newFilePlaceFromJson(newFilePlaceToJson(place)), place);
    }
  });

  test('reads nothing from JSON it did not write', () {
    expect(newFilePlaceFromJson({'folder': 1}), isNull);
    expect(newFilePlaceFromJson('f1'), isNull);
  });
}
