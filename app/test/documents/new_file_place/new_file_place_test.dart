import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_documents/truce_documents.dart';

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

  test('reads back what it writes, also the choice of none', () {
    for (final place in [
      (folderId: 'f1', subfolder: path('a/b')),
      (folderId: 'f1', subfolder: null),
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
