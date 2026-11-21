import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_files/truce_files.dart';

import '../support.dart';

void main() {
  test('an image is found by its name and never read for search', () {
    final folder = folderAt(Directory('/pictures'));
    final searchables = searchablesOf(
      [listedFile(folder, name: 'Holiday/beach.jpg')],
      filesOf: (_) => throw StateError('No image is read for search.'),
      types: appFileTypes(),
    );

    expect(searchables.single.names, contains('beach'));
    expect(searchables.single.read, isNull);
  });
}
