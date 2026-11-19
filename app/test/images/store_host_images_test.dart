import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/images/store_host_images.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_test_support/truce_test_support.dart';

import '../file_page/file_fixture.dart';

void main() {
  late FileFixture fixture;

  setUp(() async => fixture = await FileFixture.create());

  StoreHostImages imagesOf(FileSession session) =>
      StoreHostImages(fixture.imagesOf, session);

  /// The link [images] puts in for a new picture.
  Future<String> added(StoreHostImages images) async {
    final links = <String>[];
    final result = await images.add(
      Uint8List.fromList([1, 2, 3]),
      extension: 'png',
      insert: links.add,
    );
    expect(result, isA<Ok<void, StoreError>>());
    return links.single;
  }

  test('an image of ours is kept by its name, wherever its link points', () {
    const name = 'img-0123456789abcdef.png';
    final images = imagesOf(fixture.session());

    expect(images.keptAt('x/y/$name'), path('document-images/$name'));
    expect(images.keptAt('pic.png'), isNull);
  });

  test(
    'an added image is kept in the folder, linked from the document',
    () async {
      final link = await added(imagesOf(fixture.session()));

      expect(link, startsWith('document-images/img-'));
      expect(fixture.onDisk(link), isNotNull);
    },
  );

  test("an image added while a new document's place changes links from "
      'its new place', () async {
    final session = fixture.session(fixture.newFile);
    final moving = session.place(
      NewFile((
        folder: fixture.folders[1],
        subfolder: path('a'),
      ), type: fixture.newFile.type),
    );

    final link = await added(imagesOf(session));
    await moving;

    expect(link, startsWith('../document-images/img-'));
    expect(fixture.onDisk(link.substring(3), index: 1), isNotNull);
  });
}
