import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/truce_document_editor.dart';

import 'image_fakes.dart';

void main() {
  late FakePicking picking;
  late FakeKept kept;
  late List<String> hints;
  late List<String> inserted;
  late ImageInsert insert;

  setUp(() {
    picking = FakePicking(onePixelPng);
    kept = FakeKept();
    hints = [];
    inserted = [];
    insert = ImageInsert(
      () => (picking: picking, kept: kept, hint: hints.add),
      insert: inserted.add,
    );
  });

  test('a picked picture is kept, then its link inserted', () async {
    await insert.from(ImageSource.file);

    expect(inserted, ['kept/1.png']);
    expect(kept.kept.values.single, isNotEmpty);
    expect(hints, isEmpty);
    expect(insert.busy, isFalse);
  });

  test('nothing picked changes nothing', () async {
    picking.picked = null;

    await insert.from(ImageSource.file);

    expect(inserted, isEmpty);
    expect(kept.kept, isEmpty);
    expect(hints, isEmpty);
  });

  test('a file that is no image is refused with a hint', () async {
    picking.picked = Uint8List.fromList('not an image'.codeUnits);

    await insert.from(ImageSource.file);

    expect(inserted, isEmpty);
    expect(hints, ["That file isn't an image the app can show."]);
  });

  test('a folder that can not be written inserts nothing', () async {
    kept.failWith = StoreError.ioFailure;

    await insert.from(ImageSource.file);

    expect(inserted, isEmpty);
    expect(hints, ["Couldn't add the image: the folder can't be written now."]);
  });

  test('a view gone while a picture comes keeps and inserts nothing', () async {
    final adding = insert.from(ImageSource.file);
    insert.dispose();
    await adding;

    expect(inserted, isEmpty);
    expect(kept.kept, isEmpty);
  });
}
